import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

final logger = Logger();

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        logger.w('Storage permission denied');
        throw Exception('Storage permission denied');
      }
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        logger.i('Image picked: ${pickedFile.path}');
        return File(pickedFile.path);
      }
      logger.i('No image selected');
      return null;
    } catch (e) {
      logger.e('Image picking failed: $e');
      throw Exception('Image picking failed: $e');
    }
  }
}