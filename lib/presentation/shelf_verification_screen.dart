import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import '../core/widgets/camera_screen.dart';
import 'shopping_screen.dart';
import '../core/services/api_service.dart'; // IMPORT
import 'package:uuid/uuid.dart';

class ShelfVerificationScreen extends StatefulWidget {
  final String shelfId;

  const ShelfVerificationScreen({
    super.key,
    required this.shelfId,
  });

  @override
  State<ShelfVerificationScreen> createState() =>
      _ShelfVerificationScreenState();
}

class _ShelfVerificationScreenState extends State<ShelfVerificationScreen> {
  // --- Service ---
  final ApiService _apiService = ApiService(); // USE

  // --- State ---
  bool _isLoadingShelfDetails = true;
  String? _shelfFetchError;
  Map<String, dynamic>? _shelfDetails;
  bool _isVerifying = false;
  bool _isMonitoring = false;
  String? _shopId; // stored after lookup

  @override
  void initState() {
    super.initState();
    _fetchShelfDetails();
  }

  // --- REFACTORED: Uses ApiService ---
  Future<void> _fetchShelfDetails() async {
    try {
      // 1. Call AWS shelf lookup
      final shelfData = await _apiService.awsShelfLookup(widget.shelfId);

      // 2. Set state
      if (!mounted) return;
      setState(() {
        _shelfDetails = shelfData;
        _isLoadingShelfDetails = false;
      });
    } catch (e) {
      // 3. Handle errors
      if (!mounted) return;
      setState(() {
        _shelfFetchError = e.toString();
        _isLoadingShelfDetails = false;
      });
    }
  }

  // --- REFACTORED: Uses ApiService ---
  Future<void> _captureAndVerifyFace() async {
    final String? imagePath = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          scanMode: CameraScanMode.face,
        ),
      ),
    );

    if (imagePath == null || !mounted) return;

    setState(() {
      _isVerifying = true;
    });

    try {
      // 1. Read image and call service
      final imageBytes = await File(imagePath).readAsBytes();
      final String imageBase64 = base64Encode(imageBytes);

      // 'user' map now contains {'userId', 'name', 'religion'}
      // This calls your 'search_face_lambda.py'
      final user = await _apiService.verifyFace(imageBase64);

      // 2. --- NEW: Get Shelf and User data for the check ---
      // This is where the 'religion' value from your selected code is used
      final String? userReligion = user['religion'];
      final String? shelfStatus = _shelfDetails?['halal_status'];

      print('User Religion: $userReligion, Shelf Status: $shelfStatus');

      // 3. --- NEW: Implement the Access Rule ---
      if (userReligion == 'Muslim' && shelfStatus == 'Non-Halal') {
        _showError(
            'Access Denied: Your profile does not permit access to Non-Halal shelves.');
        return; // Stop execution
      }
      // --- END NEW ---

      // 4. Optionally fetch full shopper profile from carts API (DynamoDB)
      final String? shopperId = (user['userId'] ?? user['id'])?.toString();
      String? shopperEmail;
      String? shopperPhone;
      String? shopperName;
      if (shopperId != null && shopperId.isNotEmpty) {
        try {
          final shopper = await _apiService.getShopperInfo(shpUserId: shopperId);
          if (shopper != null) {
            shopperEmail = (shopper['email'] ?? '').toString().isEmpty ? null : (shopper['email'] ?? '').toString();
            shopperPhone = (shopper['phone'] ?? '').toString().isEmpty ? null : (shopper['phone'] ?? '').toString();
            shopperName = (shopper['name'] ?? '').toString().isEmpty ? null : (shopper['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      // 5. Trigger camera on the shelf device via AWS backend
      final lookup = await _apiService.awsShelfLookup(widget.shelfId);
      final String shopId = (lookup['shop_id'] ?? '').toString();
      if (shopId.isEmpty) {
        throw Exception('Shelf lookup missing shop_id');
      }
      _shopId = shopId;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Starting shelf for shop $shopId…')),
        );
      }
      final String sessionId = const Uuid().v4();
      // Get customer ID from the user object - using 'shp_user_id' as per Lambda response
      final String? customerId = user['shp_user_id']?.toString();
      print('User object: $user');
      print('Using customerId: $customerId');
      final startRes = await _apiService.awsRemoteStart(
        shopId: shopId,
        shelfId: widget.shelfId,
        sessionId: sessionId,
        customerId: customerId,
      );
      if (mounted) {
        setState(() {
          _isMonitoring = true;
        });
      }

      // 6. Inform user and proceed
      if (!mounted) return;
      final String shownSession = (startRes['session_id'] ?? sessionId).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shelf opened - Monitoring started (session: $shownSession)'),
          backgroundColor: Colors.green,
        ),
      );

      // 7. Handle success (if rule passes)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${user['name']}! Access Granted.'),
          backgroundColor: Colors.green,
        ),
      );

      // 8. Navigate
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ShoppingScreen(
            shelfId: widget.shelfId,
            userName: (shopperName ?? user['name']).toString(),
            shelfName: _shelfDetails?['shelf_name'] ?? widget.shelfId,
            shopId: shopId,
            customerId: user['shp_user_id']?.toString() ?? '',
            userEmail: shopperEmail ?? ((user['email'] ?? '').toString().isEmpty ? null : (user['email'] ?? '').toString()),
            userPhone: shopperPhone ?? ((user['phone'] ?? '').toString().isEmpty ? null : (user['phone'] ?? '').toString()),
          ),
        ),
      );
    } catch (e) {
      // 8. Handle errors
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showError(String content) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _stopShelfMonitoring() async {
    if (!_isMonitoring || _shopId == null) return;
    try {
      await _apiService.awsMobileStop(shopId: _shopId!, shelfId: widget.shelfId);
    } catch (_) {
      // swallow errors on back for smoother UX
    } finally {
      _isMonitoring = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _stopShelfMonitoring();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify Identity'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // --- MODIFIED: Use a helper to show content based on loading state ---
            child: _buildBody(),
            // --- END MODIFIED ---
          ),
        ),
      ),
    );
  }

  // --- NEW: Helper widget to manage UI state ---
  Widget _buildBody() {
    // State 1: Loading shelf details
    if (_isLoadingShelfDetails) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading Shelf Details...'),
        ],
      );
    }

    // State 2: Error loading shelf details
    if (_shelfFetchError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(_shelfFetchError!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      );
    }

    // State 3: Success, show verification content
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- NEW: Display Shelf Name and Location ---
        Text(
          _shelfDetails?['shelf_name'] ?? 'Smart Shelf', // Shelf Name (AWS)
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (_shelfDetails?['location'] != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                _shelfDetails!['location'], // Optional Location
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          'ID: ${widget.shelfId}', // The original ID
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),

        const SizedBox(height: 8),
        if (_shelfDetails?['halal_status'] != null)
          Text(
            'Status: ${_shelfDetails!['halal_status']}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _shelfDetails!['halal_status'] == 'Non-Halal'
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
          ),
        // --- END NEW ---
        const SizedBox(height: 32),
        const Icon(
          Icons.face_retouching_natural,
          size: 100,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),
        const Text(
          'Please scan your face to unlock this shelf and start shopping.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 40),
        _isVerifying
            ? const CircularProgressIndicator()
            : SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _captureAndVerifyFace,
                  icon: const Icon(Icons.camera_front),
                  label: const Text('Scan Face to Verify'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
      ],
    );
  }
  // --- END NEW ---
}
