import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onboarding_slider/flutter_onboarding_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/scan_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/results_screen.dart';
import 'screens/help_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(CounterfeitDetectorApp(cameras: cameras));
}

class CounterfeitDetectorApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CounterfeitDetectorApp({super.key, required this.cameras});

  @override
  State<CounterfeitDetectorApp> createState() => _CounterfeitDetectorAppState();
}

class _CounterfeitDetectorAppState extends State<CounterfeitDetectorApp> {
  int _currentIndex = 1; // Default to Scan tab

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirst = prefs.getBool('first_launch') ?? true;
    if (isFirst) {
      await prefs.setBool('first_launch', false);
    }
    return isFirst;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counterfeit Detector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF03DAC6)),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _isFirstLaunch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
            return OnBoardingSlider(
              headerBackgroundColor: const Color(0xFF121212),
              finishButtonText: 'Get Started',
              finishButtonStyle: const FinishButtonStyle(
                backgroundColor: Color(0xFF42A5F5),
              ),
              skipTextButton: const Text('Skip', style: TextStyle(color: Colors.white70)),
              onFinish: () {
                Navigator.pushReplacementNamed(context, '/scan');
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_drink, size: 100, color: Color(0xFF42A5F5)),
                      const SizedBox(height: 20),
                      const Text(
                        'Welcome to Counterfeit Detector',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Scan or upload images to verify the authenticity of alcohol bottles.',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt, size: 100, color: Color(0xFF42A5F5)),
                      const SizedBox(height: 20),
                      const Text(
                        'Scan with Camera',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Use the Scan tab to capture a bottle image in real-time.',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload, size: 100, color: Color(0xFF42A5F5)),
                      const SizedBox(height: 20),
                      const Text(
                        'Upload from Gallery',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Select an image from your gallery using the Upload tab.',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 100, color: Color(0xFF42A5F5)),
                      const SizedBox(height: 20),
                      const Text(
                        'View Results',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Check authenticity results and review past scans in the History tab.',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return const SizedBox(); // Placeholder until routes are loaded
        },
      ),
      initialRoute: '/scan',
      routes: {
        '/scan': (context) => ScanScreen(
              cameras: widget.cameras,
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