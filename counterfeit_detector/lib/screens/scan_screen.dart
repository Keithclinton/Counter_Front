import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../widgets/brand_dropdown.dart';
import '../screens/results_screen.dart';
import '../screens/database_helper.dart'; // Import DatabaseHelper

const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://192.168.100.15:5000/predict');

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
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  /// Shows a SnackBar with the given message.
  void _showSnackBar(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Shows an error dialog with a title, message, and retry option.
  void _showErrorDialog(String title, String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Initializes the camera, prioritizing the back camera.
  Future<void> initializeCamera() async {
    if (widget.cameras.isEmpty) {
      _showSnackBar('No cameras available');
      return;
    }

    if (await Permission.camera.request().isGranted) {
      final backCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      );
      _cameraController = CameraController(backCamera, ResolutionPreset.medium);
      try {
        await _cameraController.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      } catch (e) {
        _showSnackBar('Error initializing camera: $e');
      }
    } else {
      _showSnackBar('Camera permission denied');
    }
  }

  /// Retrieves the current location if permission is granted.
  Future<Position?> getLocation() async {
    if (await Permission.location.request().isGranted) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled');
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        _showSnackBar('Error retrieving location: $e');
        return null;
      }
    } else {
      _showSnackBar('Location permission denied');
      return null;
    }
  }

  /// Captures an image, checks server reachability, and sends it to the server.
  Future<void> captureAndSendImage() async {
    if (!_isCameraInitialized) {
      _showSnackBar('Camera is not ready');
      return;
    }
    if (_isLoading) {
      _showSnackBar('Processing in progress');
      return;
    }
    if (selectedBrand == null) {
      _showSnackBar('Please select a brand');
      return;
    }

    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5))),
    );

    try {
      // Check network connectivity
      try {
        var connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          throw Exception('No internet connection');
        }
      } catch (e) {
        throw Exception('Failed to check network connectivity: $e');
      }

      // Check server reachability
      try {
        final healthResponse = await http.get(Uri.parse('$apiUrl/health')).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('Server is not reachable'),
        );
        if (healthResponse.statusCode != 200) {
          throw Exception('Server is not reachable');
        }
      } catch (e) {
        throw Exception('Server health check failed: $e');
      }

      // Capture image
      final image = await _cameraController.takePicture();
      final imageFile = File(image.path);
      final position = await getLocation();

      // Save image to persistent storage
      final dir = await DatabaseHelper.instance.getDocumentsDirectory();
      final imageName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await imageFile.copy('${dir.path}/$imageName');

      // Prepare multipart request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      request.fields['brand'] = selectedBrand!;
      request.fields['latitude'] = position?.latitude.toString() ?? 'Unknown';
      request.fields['longitude'] = position?.longitude.toString() ?? 'Unknown';

      // Send request with timeout
      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        // Parse JSON response
        final decodedResponse = jsonDecode(responseBody);
        if (decodedResponse is Map<String, dynamic> &&
            decodedResponse.containsKey('is_authentic') &&
            decodedResponse.containsKey('brand')) {
          // Insert into database
          await DatabaseHelper.instance.insertResult({
            'brand': decodedResponse['brand'],
            'batch_no': decodedResponse['batch_no'] ?? 'Unknown',
            'date': DateFormat('dd/MM/yyyy').format(DateTime.now()),
            'confidence': decodedResponse['confidence']?.toString() ?? 'Unknown',
            'timestamp': DateTime.now().toIso8601String(),
            'is_authentic': decodedResponse['is_authentic'] ? 1 : 0,
            'image_path': savedImage.path,
            'latitude': position?.latitude.toString() ?? 'Unknown',
            'longitude': position?.longitude.toString() ?? 'Unknown',
          });

          if (!mounted) return;
          _showSnackBar('Prediction saved to history');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsScreen(
                currentIndex: widget.currentIndex,
                onTabTapped: widget.onTabTapped,
                result: responseBody,
              ),
            ),
          );
        } else {
          throw Exception('Invalid response format: Missing required fields');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      String errorMessage;
      String errorDetails;

      if (e.toString().contains('No internet connection')) {
        errorMessage = 'No Internet Connection';
        errorDetails = 'Please check your network and try again.';
      } else if (e.toString().contains('Server is not reachable') ||
          e.toString().contains('Server health check failed')) {
        errorMessage = 'Server Unreachable';
        errorDetails = 'The server is currently unavailable. Please try again later.';
      } else {
        errorMessage = 'Error';
        errorDetails = 'An unexpected error occurred: $e';
      }

      _showErrorDialog(errorMessage, errorDetails, onRetry: captureAndSendImage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
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
                            child: Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: _cameraController.value.aspectRatio,
                                  child: CameraPreview(_cameraController),
                                ),
                                Center(
                                  child: Container(
                                    width: 200,
                                    height: 300,
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Initializing camera...',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : captureAndSendImage,
                        child: const Text('Capture', style: TextStyle(fontSize: 16)),
                      ),
                      if (_isLoading) const CircularProgressIndicator(color: Colors.black),
                    ],
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
                  Navigator.pushNamed(context, '/help');
                  break;
                case 1:
                  Navigator.pushNamed(context, '/scan');
                  break;
                case 2:
                  Navigator.pushNamed(context, '/upload');
                  break;
                case 3:
                  Navigator.pushNamed(context, '/history');
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
      ),
    );
  }
}