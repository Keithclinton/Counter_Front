import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/brand_dropdown.dart';

class ScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final int currentIndex;
  final Function(int) onTabTapped;

  const ScanScreen({
    super.key,
    required this.cameras,
    required this.currentIndex,
    required this.onTabTapped,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isLoading = false;
  String? selectedBrand;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    if (widget.cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cameras available')),
      );
      return;
    }
    final backCamera = widget.cameras.first;
    _cameraController = CameraController(backCamera, ResolutionPreset.medium);
    try {
      await _cameraController.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> captureAndSendImage() async {
    setState(() => _isLoading = true);
    try {
      final image = await _cameraController.takePicture();
      final imageFile = File(image.path);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.100.15:5000/predict'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      request.fields['brand'] = selectedBrand ?? 'County';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        Navigator.pushNamed(context, '/results', arguments: responseBody);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode} - $responseBody')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing or sending image: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
              BrandDropdown(
                onBrandChanged: (brand) {
                  setState(() => selectedBrand = brand);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Align the bottle within the frame',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoading ? 'Processing...' : '🔎 Scanning Image with AI...',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF42A5F5),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : captureAndSendImage,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Capture and Analyze', style: TextStyle(fontSize: 16)),
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
        currentIndex: widget.currentIndex,
        onTap: (index) {
          widget.onTabTapped(index);
          if (index != widget.currentIndex) {
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
        selectedFontSize: 12, // Increased text size
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.help, size: 24), // Increased icon size
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