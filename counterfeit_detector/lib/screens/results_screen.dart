import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/brand_dropdown.dart';

class ResultsScreen extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const ResultsScreen({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    final String? predictionResult = ModalRoute.of(context)?.settings.arguments as String?;
    Map<String, dynamic> resultData = {
      'is_authentic': false,
      'brand': 'Unknown',
      'batch_no': 'N/A',
      'date': 'N/A',
      'confidence': 'N/A',
    };

    if (predictionResult != null) {
      try {
        resultData = jsonDecode(predictionResult);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing result: $e')),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              const BrandDropdown(),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: resultData['is_authentic'] ? const Color(0xFF2E7D32) : Colors.red,
                    width: 1.3,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      resultData['is_authentic'] ? Icons.verified : Icons.warning,
                      color: resultData['is_authentic'] ? const Color(0xFF66BB6A) : Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      resultData['is_authentic'] ? '✅ Authentic Alcohol' : '❌ Counterfeit Detected',
                      style: TextStyle(
                        color: resultData['is_authentic'] ? const Color(0xFF66BB6A) : Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Brand: ${resultData['brand']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Batch No: ${resultData['batch_no']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${resultData['date']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${resultData['confidence']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/scan'),
                  child: const Text('Back to Scan', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/help');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/scan');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/upload');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/results');
                break;
            }
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.help, size: 24),
            label: 'Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 24),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload, size: 24),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 24),
            label: 'History',
          ),
        ],
      ),
    );
  }
}