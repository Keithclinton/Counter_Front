import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:counterfeit_detector/config.dart';
import 'package:counterfeit_detector/logger.dart';

class NetworkService {
  Future<bool> checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse('${Config.apiUrl}/health'))
          .timeout(Duration(seconds: Config.healthCheckTimeoutSeconds));
      if (response.statusCode == 200) {
        AppLogger().i('Server is healthy');
        return true;
      }
      AppLogger().w('Server health check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger().e('Server health check error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> uploadImage(File image, String brand) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(Config.apiUrl));
      request.fields['brand'] = brand;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      final response = await request.send().timeout(Duration(seconds: Config.networkTimeoutSeconds));
      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        AppLogger().i('Image uploaded successfully');
        return {'status': 'success', 'data': responseData.body};
      }
      AppLogger().e('Upload failed: Status ${response.statusCode}');
      throw NetworkException('Failed to upload image: Status ${response.statusCode}');
    } catch (e) {
      AppLogger().e('Upload error: $e');
      throw NetworkException('Failed to upload image: $e');
    }
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}