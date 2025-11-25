import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../core/widgets/camera_screen.dart';
import 'shopping_screen.dart';
import '../core/services/api_service.dart';
import 'package:uuid/uuid.dart';
import 'face_liveness_webview.dart';

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
      // 1. Fetch Display Details (Stock, Halal, Location)
      // We use this result to populate the UI because the Lambda is configured for it.
      final detailedData = await _apiService.fetchShelfDetails(widget.shelfId);

      // 2. Call AWS Camera Lookup (Keep this per your request)
      // We wrap it in a try-catch so it doesn't block the UI if the camera is sleeping.
      try {
        await _apiService.awsShelfLookup(widget.shelfId);
      } catch (e) {
        print("Camera lookup warning (non-fatal): $e");
      }

      // 3. Update UI State
      if (!mounted) return;
      setState(() {
        _shelfDetails = detailedData; // Use the detailed data for the UI
        _isLoadingShelfDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shelfFetchError = e.toString();
        _isLoadingShelfDetails = false;
      });
    }
  }

  // --- REFACTORED: Uses ApiService ---
  Future<void> _captureAndVerifyFace() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      // 1. Create Session (Call your new Lambda endpoint)
      // You need to add createLivenessSession() to your ApiService
      final String sessionId = await _apiService.createLivenessSession();

      if (!mounted) return;

      // 2. Open the WebView Bridge
      final bool? isLivenessSuccessful = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceLivenessWebView(sessionId: sessionId),
        ),
      );

      // If user cancelled or liveness failed
      if (isLivenessSuccessful != true) {
        throw Exception("Liveness check failed or was cancelled.");
      }

      // 3. Verify Result & Get User Data
      // Call your new Lambda endpoint to verify session + search face
      final user = await _apiService.verifyLiveness(
        sessionId: sessionId,
        shelfId: widget.shelfId,
        action: 'unlock',
      );

      // 4. --- EXISTING LOGIC RESUMES HERE ---

      // Optionally fetch full shopper profile
      final String? shopperId =
          (user['userId'] ?? user['id'] ?? user['shp_user_id'])?.toString();
      String? shopperEmail;
      String? shopperPhone;
      String? shopperName;

      if (shopperId != null && shopperId.isNotEmpty) {
        try {
          final shopper =
              await _apiService.getShopperInfo(shpUserId: shopperId);
          if (shopper != null) {
            shopperEmail = (shopper['email'] ?? '').toString();
            shopperPhone = (shopper['phone'] ?? '').toString();
            shopperName = (shopper['name'] ?? '').toString();
          }
        } catch (_) {
          // Ignore cart errors, we have basic user info
        }
      }

      // 5. Trigger Camera / Unlock Shelf
      if (_shelfDetails == null) {
        await _fetchShelfDetails();
      }

      final String shopId = (_shelfDetails?['shop_id'] ?? '').toString();
      if (shopId.isEmpty) throw Exception('Shelf lookup missing shop_id');

      _shopId = shopId;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Starting shelf for shop $shopId…')),
        );
      }

      final String sessionUuid = const Uuid().v4();
      final String? customerId = user['shp_user_id']?.toString();

      final startRes = await _apiService.awsRemoteStart(
        shopId: shopId,
        shelfId: widget.shelfId,
        sessionId: sessionUuid,
        customerId: customerId,
      );

      if (mounted) {
        setState(() {
          _isMonitoring = true;
        });
      }

      // 6. Success Message & Navigation
      if (!mounted) return;
      final String shownSession =
          (startRes['session_id'] ?? sessionUuid).toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${user['name']}! Access Granted.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ShoppingScreen(
            shelfId: widget.shelfId,
            userName: (shopperName ?? user['name']).toString(),
            shelfName: _shelfDetails?['shelf_name'] ?? widget.shelfId,
            shopId: shopId,
            customerId: customerId ?? '',
            userEmail: shopperEmail ?? (user['email']?.toString()),
            userPhone: shopperPhone ?? (user['phone']?.toString()),
          ),
        ),
      );
    } catch (e) {
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
      await _apiService.mobileStop(shopId: _shopId!, shelfId: widget.shelfId);
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

    if (_shelfFetchError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          Text('Error loading details',
              style: Theme.of(context).textTheme.titleLarge),
          Text(_shelfFetchError!, textAlign: TextAlign.center),
        ],
      );
    }

    // Extract Data safely
    final String shelfName = _shelfDetails?['shelf_name'] ?? 'Smart Shelf';
    final String location = _shelfDetails?['location'] ?? 'Unknown';
    final String halalStatus = _shelfDetails?['halal_status'] ?? 'Unknown';
    final int currentStock = _shelfDetails?['current_stock'] ?? 0;

    final bool isHalal = halalStatus == 'Halal';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. NAME AND LOCATION
        Text(
          shelfName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              location,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2. STOCK AND HALAL CHIPS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stock Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Stock: $currentStock',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Halal Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isHalal ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isHalal ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isHalal ? Icons.check_circle_outline : Icons.no_food,
                    size: 18,
                    color: isHalal ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    halalStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isHalal ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // 3. FACE SCAN PROMPT
        const Icon(
          Icons.face_retouching_natural,
          size: 100,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),
        const Text(
          'Please scan your face to unlock this shelf.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 40),

        // 4. ACTION BUTTON
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
