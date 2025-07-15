import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:counterfeit_detector/services/camera_service.dart';
import 'package:counterfeit_detector/services/storage_service.dart';
import 'package:counterfeit_detector/services/network_service.dart';
import 'package:counterfeit_detector/services/permission_service.dart';
import 'package:counterfeit_detector/widgets/brand_dropdown.dart';
import 'package:counterfeit_detector/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ScanScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final CameraService cameraService;

  const ScanScreen({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.cameraService,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final StorageService _storageService;
  late final NetworkService _networkService;
  late final PermissionService _permissionService;
  bool _isLoading = false;
  String? _selectedBrand;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _networkService = NetworkService();
    _permissionService = PermissionService();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.cameraService.initializeCamera();
      final lastBrand = await _storageService.getLastBrand();
      if (mounted) {
        setState(() => _selectedBrand = lastBrand);
      }
      if (await _storageService.isFirstScan() && mounted) {
        setState(() => _showOnboarding = true);
      }
    } catch (e) {
      _showSnackBar('Failed to initialize: $e');
    }
  }

  Future<void> _scan() async {
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
      final position = await _permissionService.getLocation();
      final imageFile = await widget.cameraService.captureImage();
      final response = await _networkService.uploadImage(imageFile, _selectedBrand!);
      final savedImage = await _saveImage(imageFile);

      await _storageService.saveResult(response, savedImage.path, position);
      await _storageService.saveLastBrand(_selectedBrand!);

      if (_showOnboarding && mounted) {
        await _storageService.completeOnboarding();
        setState(() => _showOnboarding = false);
      }

      if (mounted) {
        Navigator.pushNamed(context, '/results', arguments: json.encode(response));
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _getUserFriendlyError(e),
          onSettings: e is PermissionException && e.message.contains('permanently')
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

  Future<File> _saveImage(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = await image.copy('${dir.path}/$filename');
    if (await image.exists()) {
      await image.delete();
      AppLogger().i('Temporary image file deleted');
    }
    return savedImage;
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is PermissionException) {
      return error.message.contains('permanently')
          ? 'Permission permanently denied. Please enable in settings.'
          : 'Permission denied. Please allow camera and location access.';
    } else if (error is CameraException) {
      return 'Camera error. Please try again.';
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
    widget.cameraService.dispose();
    super.dispose();
    AppLogger().i('ScanScreen disposed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Scan', style: TextStyle(color: Colors.white)),
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
                  ElevatedButton(
                    onPressed: _scan,
                    style: theme.elevatedButtonTheme.style,
                    child: const Text('Scan Product'),
                  ),
                  if (_showOnboarding)
                    const Text(
                      'Welcome! Please select a brand and scan a product.',
                      style: TextStyle(color: Colors.white70),
                    ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
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