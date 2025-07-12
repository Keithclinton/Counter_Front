import 'dart:convert';
import 'package:counterfeit_detector/logger.dart';

class ResultProcessor {
  Map<String, dynamic> processResult(String response) {
    try {
      final decoded = jsonDecode(response) as Map<String, dynamic>;
      AppLogger().i('Result processed: ${decoded['brand']}');
      return decoded;
    } catch (e) {
      AppLogger().e('Error processing result: $e');
      throw ResultException('Failed to process result: $e');
    }
  }
}

class ResultException implements Exception {
  final String message;
  ResultException(this.message);
  @override
  String toString() => message;
}