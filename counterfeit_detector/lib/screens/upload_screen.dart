import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
  File? _imageFile;
  bool _isLoading = false;
  String? selectedBrand;

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> analyzeImage() async {
    if (_imageFile == null) return;
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.100.15:5000/predict'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path),
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
        SnackBar(content: Text('Error sending image: $e')),
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
            children: [
              BrandDropdown(
                onBrandChanged: (brand) {
                  setState(() => selectedBrand = brand);
                },
              ),
              const SizedBox(height: 20),
              _imageFile != null
                  ? Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF42A5F5), width: 1.3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
                    )
                  : Container(
                      height: 250,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade800, width: 1.2),
                      ),
                      child: const Text(
                        'No image selected',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
                        backgroundColor: const Color(0xFF1F1F1F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: pickImage,
                      child: const Text(
                        'Choose Image',
                        style: TextStyle(color: Color(0xFF42A5F5), fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
                        backgroundColor: _imageFile != null && !_isLoading
                            ? const Color(0xFF42A5F5)
                            : Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _imageFile != null && !_isLoading ? analyzeImage : null,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              'Analyze Image',
                              style: TextStyle(
                                color: _imageFile != null && !_isLoading
                                    ? Colors.black
                                    : Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
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