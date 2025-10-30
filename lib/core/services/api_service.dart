import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

/// A service class to handle all API network calls.
class ApiService {
  // --- Base URL for your API ---
  final String _baseUrl =
      "https://yzrixheojf.execute-api.ap-southeast-1.amazonaws.com/dev";

  /// Throws an exception if the network call fails.
  /// Returns the S3 object key on success.
  Future<String> uploadFaceToS3(String imagePath) async {
    final getUrlResponse = await http.get(Uri.parse('$_baseUrl/upload-url'));

    if (getUrlResponse.statusCode != 200) {
      throw Exception('Could not get upload URL.');
    }

    final uploadData = jsonDecode(getUrlResponse.body);
    final String presignedUrl = uploadData['uploadUrl'];
    final String objectKey = uploadData['objectKey'];

    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    final uploadResponse = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: bytes,
    );

    if (uploadResponse.statusCode == 200) {
      return objectKey;
    } else {
      throw Exception('Failed to upload image to S3.');
    }
  }

  /// Throws an exception if the network call fails.
  /// Returns the decoded JSON response on success.
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseBody;
    } else {
      // Throw the error message from the Lambda
      throw Exception(
          responseBody['error'] ?? 'An unknown registration error occurred.');
    }
  }

  /// Throws an exception if the network call fails.
  /// Returns the decoded shelf details map on success.
  Future<Map<String, dynamic>> fetchShelfDetails(String shelfId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/shelf-details?shelfId=$shelfId'),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Return just the shelf object
      return responseBody['shelf'];
    } else {
      throw Exception(responseBody['error'] ?? 'Shelf not found.');
    }
  }

  /// Throws an exception if the network call fails.
  /// Returns the decoded user map on success.
  Future<Map<String, dynamic>> verifyFace(String imageBase64) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/search-face'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageBase64': imageBase64}),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Return just the user object
      return responseBody['user'];
    } else {
      throw Exception(responseBody['error'] ?? 'Face not recognized.');
    }
  }

  /// Throws an exception if the network call fails.
  /// Returns the decoded product response map on success.
  Future<Map<String, dynamic>> fetchShelfProducts(String shelfId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/shelf-products?shelfId=$shelfId'),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseBody;
    } else {
      throw Exception(responseBody['error'] ?? 'Failed to load products.');
    }
  }
}
