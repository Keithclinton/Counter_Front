import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:counterfeit_detector/services/image_picker_service.dart';
import 'package:counterfeit_detector/services/permission_service.dart';
import 'package:counterfeit_detector/services/network_service.dart';
import 'package:counterfeit_detector/widgets/brand_dropdown.dart';
import 'package:counterfeit_detector/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

class UploadScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const UploadScreen({super.key, required this.currentIndex, required this.onTabTapped});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final ImagePickerService _imagePickerService;
  late final PermissionService _permissionService;
  late final NetworkService _networkService;
  File? _image;
  bool _isLoading = false;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    _imagePickerService = ImagePickerService();
    _permissionService = PermissionService();
    _networkService = NetworkService();
  }

  Future<void> _pickAndUploadImage() async {
    if (_isLoading || _selectedBrand == null) return;
    setState(() => _isLoading = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none && mounted) {
        _showSnackBar('No internet connection');
        return;
      }

      if (!await _networkService.checkServerHealth()) {
        _showSnackBar('Server is not available');
        return;
      }

      await _permissionService.requestCameraPermission();
      final imageFile = await _imagePickerService.pickImage(); // <-- No arguments
      if (imageFile == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final filename = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await imageFile.copy('${dir.path}/$filename');

      final position = await _permissionService.getLocation();
      final response = await _networkService.uploadImage(savedImage, _selectedBrand!);

      if (mounted) {
        setState(() => _image = savedImage);
        Navigator.pushNamed(context, '/results', arguments: json.encode(response));
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _getUserFriendlyError(e),
          onSettings: e.toString().contains('permission')
              ? () => openAppSettings()
              : null,
        );
        await FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error.toString().contains('pick image')) {
      return 'Failed to pick image. Please try again.';
    } else if (error.toString().contains('permission')) {
      return error.toString().contains('permanently')
          ? 'Permission permanently denied. Please enable in settings.'
          : 'Permission denied. Please allow access.';
    } else if (error is NetworkException) {
      return 'Network error. Please check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showSnackBar(String message, {VoidCallback? onSettings}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        action: onSettings != null
            ? SnackBarAction(
                label: 'Settings',
                textColor: const Color(0xFF42A5F5),
                onPressed: onSettings,
              )
            : null,
      ),
    );
    AppLogger().i('SnackBar: $message');
  }

  @override
  void dispose() {
    super.dispose();
    AppLogger().i('UploadScreen disposed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  BrandDropdown(
                    value: _selectedBrand,
                    onChanged: (brand) {
                      setState(() => _selectedBrand = brand);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_image != null)
                    Image.file(
                      _image!,
                      height: 200,
                      fit: BoxFit.cover,
                    ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _pickAndUploadImage,
                    style: theme.elevatedButtonTheme.style,
                    child: const Text('Upload Image'),
                  ),
                ],
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