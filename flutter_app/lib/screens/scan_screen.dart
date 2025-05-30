import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../widgets/brand_dropdown.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.first;

    _cameraController = CameraController(backCamera, ResolutionPreset.medium);
    await _cameraController.initialize();

    if (mounted) {
      setState(() => _isCameraInitialized = true);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Brand Dropdown
              const BrandDropdown(),

              const SizedBox(height: 20),

              // Instruction Text
              const Text(
                'Align the bottle within the frame',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),

              const SizedBox(height: 10),

              // Camera Preview Container with rounded corners and border
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800, width: 1.2),
                ),
                child: _isCameraInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CameraPreview(_cameraController),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF42A5F5),
                        ),
                      ),
              ),

              const SizedBox(height: 10),

              // AI scanning status text
              const Text(
                '🔎 Scanning Image with AI...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF42A5F5),
                  fontStyle: FontStyle.italic,
                ),
              ),

              const Spacer(),

              // Capture Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    // TODO: Capture and send image to backend
                    Navigator.pushNamed(context, '/results');
                  },
                  child: const Text('Capture and Analyze', style: TextStyle(fontSize: 16)),
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
                    navItem('Scan', true),
                    navItem('History', false),
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
