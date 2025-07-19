import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class PermissionService {
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    logger.i('Camera permission status: $status');
    return status.isGranted;
  }

  Future<Position?> getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      logger.w('Location services disabled');
      return null;
    }
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        logger.i('Location retrieved: ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e) {
        logger.e('Location retrieval failed: $e');
        return null;
      }
    } else if (status.isPermanentlyDenied) {
      logger.w('Location permission permanently denied');
      throw Exception('Location permission permanently denied');
    } else {
      logger.w('Location permission denied');
      throw Exception('Location permission denied');
    }
  }
}