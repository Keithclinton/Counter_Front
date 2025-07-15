import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const HelpScreen({super.key, required this.currentIndex, required this.onTabTapped});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Help', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(
        child: Text(
          'Help content goes here',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1B1B1B),
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: currentIndex,
        onTap: (index) {
          onTabTapped(index);
          if (index != currentIndex) {
            final routes = ['/help', '/scan', '/upload', '/history'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.help, size: 28), label: 'Help'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt, size: 28), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.upload, size: 28), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.history, size: 28), label: 'History'),
        ],
      ),
    );
  }
}