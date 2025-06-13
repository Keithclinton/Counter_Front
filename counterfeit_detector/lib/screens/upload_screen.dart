import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/brand_dropdown.dart';

class UploadScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const UploadScreen({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  bool _isLoading = false;
  String? selectedBrand;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (await Permission.storage.request().isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
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

  Future<void> _uploadAndSendImage() async {
    if (_image == null || _isLoading) return;

    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
      ),
    );

    try {
      final position = await getLocation();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.100.15:5000/predict'), // Update if needed
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', _image!.path),
      );
      request.fields['brand'] = selectedBrand ?? 'County';
      request.fields['latitude'] = position?.latitude.toString() ?? 'Unknown';
      request.fields['longitude'] = position?.longitude.toString() ?? 'Unknown';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushNamed(context, '/results', arguments: responseBody);
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode} - $responseBody')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
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
                'Select an image to analyze',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoading ? 'Processing...' : '🔎 Ready to Analyze',
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
                  child: _image == null
                      ? const Center(
                          child: Text(
                            'No image selected',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_image!, fit: BoxFit.cover),
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
                  onPressed: _pickImage,
                  child: const Text('Pick Image', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _uploadAndSendImage,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Analyze Image', style: TextStyle(fontSize: 16)),
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