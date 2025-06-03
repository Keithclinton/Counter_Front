import 'package:flutter/material.dart';

import '../widgets/brand_dropdown.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              // Brand Dropdown (optional here if you want)
              const BrandDropdown(),

              const SizedBox(height: 20),

              // Result Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2E7D32), width: 1.3),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF66BB6A), size: 48),
                    const SizedBox(height: 10),
                    const Text(
                      '✅ Authentic Alcohol',
                      style: TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Brand: Black Eagle',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Batch No: BEX-2025',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Date: 30 May 2025',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/home'),
                  child: const Text('Back to Home', style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Navigation Bar
              Container(
                height: 65,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1B1B),
                  border: Border(top: BorderSide(color: Colors.grey, width: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    navItem('Help', false),
                    navItem('Scan', false),
                    navItem('History', true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget navItem(String label, bool active) {
    Color activeColor = const Color(0xFF1E88E5);
    Color inactiveColor = Colors.grey.shade600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          active ? '⬤' : '○',
          style: TextStyle(fontSize: 16, color: active ? activeColor : inactiveColor),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: active ? activeColor : inactiveColor),
        ),
      ],
    );
  }
}
