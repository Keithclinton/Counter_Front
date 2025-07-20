import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:counterfeit_detector/config.dart';
import 'package:counterfeit_detector/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class NetworkService {
  final String baseUrl = 'https://fastapi-tf-79035170475.africa-south1.run.app/';

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
      final uri = Uri.parse('${Config.apiUrl}/predict');
      final request = http.MultipartRequest('POST', uri);
      request.fields['brand'] = brand;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'image', // <-- change from 'file' to 'image'
            bytes,
            filename: 'upload.png',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path), // <-- change from 'file' to 'image'
        );
      }

      final streamedResponse = await request.send().timeout(Duration(seconds: Config.networkTimeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        AppLogger().i('Image uploaded successfully');
        return json.decode(response.body) as Map<String, dynamic>;
      }
      AppLogger().e('Upload failed: Status ${response.statusCode}, Body: ${response.body}');
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