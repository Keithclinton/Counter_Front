import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Added for network check
import '../widgets/brand_dropdown.dart';
import '../screens/results_screen.dart'; // Import ResultsScreen

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

    if (await Permission.camera.request().isGranted) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
    }
  }

  Future<Position?> getLocation() async {
    if (await Permission.location.request().isGranted) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return null;
    }
  }

  Future<void> captureAndSendImage() async {
    if (!_isCameraInitialized || _isLoading) return;

    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
      ),
    );

    try {
      final image = await _cameraController.takePicture();
      final imageFile = File(image.path);
      final position = await getLocation();

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.100.15:5000/predict'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      request.fields['brand'] = selectedBrand ?? 'County';
      request.fields['latitude'] = position?.latitude.toString() ?? 'Unknown';
      request.fields['longitude'] = position?.longitude.toString() ?? 'Unknown';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Response body: $responseBody'); // Debug log

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        try {
          final decodedResponse = jsonDecode(responseBody);
          if (decodedResponse is Map<String, dynamic> &&
              decodedResponse.containsKey('is_authentic') &&
              decodedResponse.containsKey('brand')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultsScreen(
                  currentIndex: widget.currentIndex,
                  onTabTapped: widget.onTabTapped,
                  result: responseBody, // Pass the JSON string as result
                ),
              ),
            );
          } else {
            throw Exception('Invalid response format');
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid response: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode} - $responseBody')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      String errorMessage = e.toString().contains('No internet connection')
          ? 'No Internet Connection'
          : 'Error: $e';
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              errorMessage == 'No Internet Connection'
                  ? 'Please check:\n\n• Network cables\n• Modem & router\n• Wi-Fi status\n\nThen try again.'
                  : 'An unexpected error occurred. Please try again.',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  captureAndSendImage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          );
        },
      );
    } finally {
      setState(() => _isLoading = false);
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
                _isLoading ? 'Processing...' : 'Scanning Image...',
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
                      : const Text('Capture', style: TextStyle(fontSize: 16)),
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
                Navigator.pushReplacementNamed(context, '/history');
                break;
            }
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.help, size: 28),
            label: 'Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 28),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload, size: 28),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 28),
            label: 'History',
          ),
        ],
      ),
    );
  }
}