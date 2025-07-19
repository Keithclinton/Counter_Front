import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://fastapi-tf-79035170475.africa-south1.run.app';

  static Future<List<dynamic>> fetchLocations() async {
    final response = await http.get(Uri.parse('$baseUrl/api/locations'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load locations');
    }
  }

  // Add more methods for other endpoints as needed
}