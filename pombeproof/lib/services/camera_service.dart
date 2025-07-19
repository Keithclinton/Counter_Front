import 'dart:io';
import 'package:camera/camera.dart';
import 'package:counterfeit_detector/logger.dart';

class CameraService {
  final List<CameraDescription> cameras;
  CameraController? _controller;

  CameraService(this.cameras);

  CameraController? get controller => _controller;

  Future<void> initializeCamera() async {
    try {
      if (cameras.isEmpty) {
        AppLogger().e('No cameras available');
        throw CameraException('No cameras available', 'no_cameras');
      }
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(backCamera, ResolutionPreset.low);
      await _controller!.initialize();
      AppLogger().i('Camera initialized');
    } catch (e) {
      AppLogger().e('Camera initialization failed: $e');
      throw CameraException('Failed to initialize camera', 'init_failed');
    }
  }

  Future<File> captureImage() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        throw CameraException('Camera not initialized', 'not_initialized');
      }
      final XFile file = await _controller!.takePicture();
      AppLogger().i('Image captured: ${file.path}');
      return File(file.path);
    } catch (e) {
      AppLogger().e('Error capturing image: $e');
      throw CameraException('Failed to capture image', 'capture_failed');
    }
  }

  void dispose() {
    _controller?.dispose();
    AppLogger().i('CameraService disposed');
  }
}