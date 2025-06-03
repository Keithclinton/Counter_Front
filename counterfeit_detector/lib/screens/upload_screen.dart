// lib/screens/upload_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/brand_dropdown.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _imageFile;

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
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
              // Brand Dropdown (reusable widget)
              const BrandDropdown(),

              const SizedBox(height: 20),

              // Image preview or placeholder
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

              // Buttons: Choose Image & Analyze Image
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
                        backgroundColor: _imageFile != null ? const Color(0xFF42A5F5) : Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _imageFile != null
                          ? () => Navigator.pushNamed(context, '/results')
                          : null,
                      child: Text(
                        'Analyze Image',
                        style: TextStyle(
                          color: _imageFile != null ? Colors.black : Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Bottom Navigation Bar (reuse from ScanScreen if you want)
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
