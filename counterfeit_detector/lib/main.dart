import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/results_screen.dart';
import 'screens/help_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counterfeit Detector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF03DAC6)),
        useMaterial3: true,
      ),
      initialRoute: '/scan',
      routes: {
        '/scan': (context) => ScanScreen(
              cameras: widget.cameras,
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
        '/upload': (context) => UploadScreen( // Ensure correct class name
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
      },
    );
  }
}