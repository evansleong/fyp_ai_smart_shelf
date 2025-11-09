import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

/// A service class to handle all API network calls.
class ApiService {
  // --- Base URL for your API ---
  final String _baseUrl =
      "https://yzrixheojf.execute-api.ap-southeast-1.amazonaws.com/dev";
  // AWS REST API (prod) for camera endpoints
  final String _awsProdBase =
      "https://twhhc88zla.execute-api.ap-southeast-1.amazonaws.com/prod";

  Future<bool> checkIcExists(String icNumber) async {
    final response = await http.get(
      // Assumes your new endpoint is /check-ic
      Uri.parse('$_baseUrl/check-ic?icNumber=$icNumber'),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Return the 'exists' boolean from the Lambda
      return responseBody['exists'] ?? false;
    } else if (response.statusCode == 400) {
      throw Exception(responseBody['error'] ?? 'IC Number was not provided.');
    } else {
      // Throw any other error from the Lambda
      throw Exception(responseBody['error'] ??
          'An unknown error occurred while checking IC.');
    }
  }

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
  Future<Map<String, dynamic>> verifyFace(String imageBase64,
      {String action = 'login', String? shelfId}) async {
    // <-- 1. ADD shelfId HERE

    // Create the request body
    final Map<String, dynamic> body = {
      // <-- 2. CREATE THIS MAP
      'imageBase64': imageBase64,
      'action': action,
    };

    // Add shelfId ONLY if it's provided
    if (shelfId != null) {
      // <-- 3. ADD THIS IF-STATEMENT
      body['shelfId'] = shelfId;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/search-face'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body), // <-- 4. SEND THE NEW body
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Return just the user object
      return responseBody['user'];
    } else {
      final String errorMessage =
          responseBody['error'] ?? 'An unknown error occurred.';
      throw Exception(errorMessage);
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

  // ===== AWS Camera API (REST) =====
  // GET /camera/shelf/{shelf_id}
  Future<Map<String, dynamic>> awsShelfLookup(String shelfId) async {
    final uri = Uri.parse('$_awsProdBase/camera/shelf/$shelfId');
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
    });
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return body as Map<String, dynamic>;
    } else if (res.statusCode == 404) {
      throw Exception(body['error'] ?? 'Shelf not found');
    } else if (res.statusCode == 400) {
      throw Exception(body['error'] ?? 'Invalid request');
    } else {
      throw Exception(body['error'] ?? 'Server error');
    }
  }

  Future<Map<String, dynamic>> getCustomerCart({
    required String customerId,
    required String shopId,
  }) async {
    final uri = Uri.parse('$_awsProdBase/carts');
    final payload = {
      'action': 'get_cart',
      'params': {
        'customer_id': customerId,
        'shop_id': shopId,
      }
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return body as Map<String, dynamic>;
    } else if (res.statusCode == 400) {
      throw Exception(body['message'] ?? 'Invalid request');
    } else if (res.statusCode == 404) {
      throw Exception(body['message'] ?? 'Cart not found');
    } else {
      throw Exception(body['message'] ?? 'Server error');
    }
  }

  Future<Map<String, dynamic>?> getShopperInfo({
    required String shpUserId,
  }) async {
    final uri = Uri.parse('$_awsProdBase/carts');
    final payload = {
      'action': 'get_shopper',
      'params': {
        'shp_user_id': shpUserId,
      }
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      final data = body as Map<String, dynamic>;
      if (data['success'] == true && data['shopper'] is Map<String, dynamic>) {
        return data['shopper'] as Map<String, dynamic>;
      }
      return null;
    } else if (res.statusCode == 400) {
      throw Exception(body['message'] ?? 'Invalid request');
    } else if (res.statusCode == 404) {
      throw Exception(body['message'] ?? 'Shopper not found');
    } else {
      throw Exception(body['message'] ?? 'Server error');
    }
  }

  /// Fetches a list of formatted orders for a specific customer.
  /// Throws an exception if the network call fails.
  Future<List<dynamic>> getCustomerOrders(String customerId) async {
    // You'll need to create this endpoint in your API Gateway.
    // I'm using '/orders/{customerId}' as an example.
    final response = await http.get(
      Uri.parse('$_baseUrl/orders/$customerId'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Assumes the API returns a list of orders, e.g., { "orders": [...] }
      return responseBody['orders'] as List<dynamic>;
    } else {
      throw Exception(responseBody['error'] ?? 'Failed to load orders.');
    }
  }

  Future<List<dynamic>> findNearbyShelves(
    double latitude,
    double longitude,
  ) async {
    // Note: This calls _baseUrl, which points to your shelf-service lambda
    final uri = Uri.parse('$_awsProdBase/shelf');
    final payload = {
      'action': 'find_nearby_shelves',
      'params': {
        'latitude': latitude,
        'longitude': longitude,
      }
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['success'] == true) {
      // Return the list of shop objects
      return responseBody['shelves'] as List<dynamic>;
    } else {
      throw Exception(responseBody['message'] ?? 'Failed to find nearby shelves.');
    }
  }

  // POST /camera/remote-start/{shop_id}/{shelf_id}
  Future<Map<String, dynamic>> awsRemoteStart({
    required String shopId,
    required String shelfId,
    String? sessionId,
    String? customerId,
    String? shpUserId,
  }) async {
    final uri = Uri.parse('$_awsProdBase/camera/remote-start/$shopId/$shelfId');
    final payload = <String, dynamic>{};
    if (sessionId != null) payload['session_id'] = sessionId;
    if (customerId != null) payload['customer_id'] = customerId;
    if (shpUserId != null) payload['shp_user_id'] = shpUserId;
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: payload.isEmpty ? null : jsonEncode(payload),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return body as Map<String, dynamic>;
    } else if (res.statusCode == 404) {
      throw Exception(body['error'] ?? 'Shelf not found');
    } else if (res.statusCode == 400) {
      throw Exception(body['error'] ?? 'Invalid request');
    } else {
      throw Exception(body['error'] ?? 'Server error');
    }
  }

  // POST /camera/mobile-stop/{shop_id}/{shelf_id}
  /// Fire-and-forget variant with short timeout and quick retries.
  /// Does not throw; best-effort only.
  Future<void> mobileStop({
    required String shopId,
    required String shelfId,
  }) async {
    final uri = Uri.parse('$_awsProdBase/camera/mobile-stop/$shopId/$shelfId');
    int attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final res = await http.post(uri, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 6));
        if (res.statusCode >= 200 && res.statusCode < 300) return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }
}
