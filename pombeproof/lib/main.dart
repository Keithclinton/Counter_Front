import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // <-- Add this line
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onboarding_slider/flutter_onboarding_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:counterfeit_detector/screens/scan_screen.dart';
import 'package:counterfeit_detector/screens/upload_screen.dart';
import 'package:counterfeit_detector/screens/results_screen.dart';
import 'package:counterfeit_detector/screens/help_screen.dart';
import 'package:counterfeit_detector/screens/history_screen.dart';
import 'package:logger/logger.dart';
import 'package:counterfeit_detector/services/camera_service.dart'; // <-- Add this import
import 'firebase_options.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }
  final cameras = await availableCameras();
  logger.i('Main: App initialized with ${cameras.length} cameras');
  runApp(CounterfeitDetectorApp(cameras: cameras));
}

class CounterfeitDetectorApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CounterfeitDetectorApp({super.key, required this.cameras});

  @override
  State<CounterfeitDetectorApp> createState() => _CounterfeitDetectorAppState();
}

class _CounterfeitDetectorAppState extends State<CounterfeitDetectorApp> {
  int _currentIndex = 1;

  late final CameraService cameraService;

  @override
  void initState() {
    super.initState();
    cameraService = CameraService(widget.cameras); // Pass the whole list
    cameraService.initializeCamera(); // Initialize the camera
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      logger.i('Main: Tab changed to index $index');
    });
  }

  Future<bool> _isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isFirst = prefs.getBool('first_launch') ?? true;
      if (isFirst) {
        await prefs.setBool('first_launch', false);
      }
      logger.i('Main: First launch check completed, isFirst: $isFirst');
      return isFirst;
    } catch (e) {
      logger.e('Main: Error in _isFirstLaunch: $e');
      await FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counterfeit Detector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42A5F5),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
          bodySmall: TextStyle(color: Colors.white70, fontSize: 14),
          labelLarge: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF42A5F5),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            minimumSize: const Size(200, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _isFirstLaunch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            logger.i('Main: FutureBuilder waiting');
            return const Scaffold(
              backgroundColor: Colors.red, // Debug: Red to confirm rendering
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF42A5F5)),
                    SizedBox(height: 10),
                    Text(
                      'Loading Counterfeit Detector...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            logger.e('Main: FutureBuilder error: ${snapshot.error}');
            FirebaseCrashlytics.instance.recordError(snapshot.error, snapshot.stackTrace);
            return Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Error loading app',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: Theme.of(context).elevatedButtonTheme.style,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.data == true) {
            logger.i('Main: Showing OnBoardingSlider');
            return OnBoardingSlider(
              headerBackgroundColor: const Color(0xFF121212),
              finishButtonText: 'Get Started',
              finishButtonStyle: FinishButtonStyle(
                backgroundColor: const Color(0xFF42A5F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              skipTextButton: Semantics(
                label: 'Skip onboarding',
                child: const Text('Skip', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
              onFinish: () {
                logger.i('Main: OnBoardingSlider finished, navigating to ScanScreen');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScanScreen(
                      cameraService: cameraService,
                      currentIndex: _currentIndex,
                      onTabTapped: _onTabTapped,
                    ),
                  ),
                );
              },
              background: [
                Container(color: const Color(0xFF121212)),
                Container(color: const Color(0xFF121212)),
                Container(color: const Color(0xFF121212)),
                Container(color: const Color(0xFF121212)),
              ],
              totalPage: 4,
              speed: 1.8,
              pageBodies: [
                Semantics(
                  label: 'Welcome slide',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_drink, size: 100, color: Color(0xFF42A5F5))
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome to Counterfeit Detector',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 800.ms),
                        const SizedBox(height: 10),
                        Text(
                          'Scan or upload images to verify the authenticity of alcohol bottles.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 1000.ms),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: 'Scan slide',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 100, color: Color(0xFF42A5F5))
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(),
                        const SizedBox(height: 20),
                        Text(
                          'Scan with Camera',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 800.ms),
                        const SizedBox(height: 10),
                        Text(
                          'Use the Scan tab to capture a bottle image in real-time.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 1000.ms),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: 'Upload slide',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload, size: 100, color: Color(0xFF42A5F5))
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(),
                        const SizedBox(height: 20),
                        Text(
                          'Upload from Gallery',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 800.ms),
                        const SizedBox(height: 10),
                        Text(
                          'Select an image from your gallery using the Upload tab.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 1000.ms),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: 'History slide',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history, size: 100, color: Color(0xFF42A5F5))
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(),
                        const SizedBox(height: 20),
                        Text(
                          'View Results',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 800.ms),
                        const SizedBox(height: 10),
                        Text(
                          'Check authenticity results and review past scans in the History tab.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 1000.ms),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          logger.i('Main: Navigating to ScanScreen');
          return ScanScreen(
            cameraService: cameraService,
            currentIndex: _currentIndex,
            onTabTapped: _onTabTapped,
          );
        },
      ),
      routes: {
        '/scan': (context) => ScanScreen(
              cameraService: cameraService,
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
        '/upload': (context) => UploadScreen(
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
        '/results': (context) => ResultsScreen(
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
        '/help': (context) => HelpScreen(
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
        '/history': (context) => HistoryScreen(
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
      },
    );
  }
}