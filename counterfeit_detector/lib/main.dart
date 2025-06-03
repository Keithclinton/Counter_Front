import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/results_screen.dart';

void main() {
  runApp(const CounterfeitDetectorApp());
}

class CounterfeitDetectorApp extends StatelessWidget {
  const CounterfeitDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counterfeit Detector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF03DAC6)),
        useMaterial3: true,
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => const ScanScreen(),
        '/upload': (context) => const UploadScreen(),
        '/results': (context) => const ResultsScreen(),
      },
    );
  }
}
