import 'package:flutter/material.dart';
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

      await _apiService.awsRemoteStart(
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
    final String shopName =
        _shelfDetails?['shop_name'] ?? 'Smart Shop'; // <--- NEW
    final String shelfName = _shelfDetails?['shelf_name'] ?? 'Smart Shelf';
    final String location = _shelfDetails?['location'] ?? 'Unknown';
    final String halalStatus = _shelfDetails?['halal_status'] ?? 'Unknown';
    final int currentStock = _shelfDetails?['current_stock'] ?? 0;
    final bool isHalal = halalStatus == 'Halal';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShelfInfoHeader(
          shopName: shopName,
          shelfName: shelfName,
          halalStatus: halalStatus,
          isHalal: isHalal,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Ready Stock',
                value: '$currentStock items',
                icon: Icons.inventory_rounded,
                accentColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Shelf Location',
                value: location,
                icon: Icons.place_outlined,
                accentColor: Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _InstructionCard(isHalal: isHalal),
        const SizedBox(height: 32),
        _isVerifying
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _captureAndVerifyFace,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock Shelf'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
        const SizedBox(height: 12),

        // TEST
        // TEST
        // TEST
        // TEST
        // TEST
        if (!_isVerifying)
          TextButton.icon(
            onPressed: _debugForceUnlock,
            icon: const Icon(Icons.bug_report, color: Colors.red),
            label: const Text(
              "DEBUG: FORCE UNLOCK",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          // TEST
          // TEST
          // TEST
          // TEST
          // TEST
      ],
    );
  }

  //TEST ONLY
  //TEST ONLY
  //TEST ONLY
  //TEST ONLY
  //TEST ONLY
  Future<void> _debugForceUnlock() async {
    setState(() => _isVerifying = true);

    try {
      // 1. HARDCODED DATA (From your provided Table - Row 1)
      const String debugShopId = '3bda9261-977a-498b-9b09-d39e8276e582';
      const String debugShelfId = '54eebf87-d2b1-41bf-a9e4-ec7427b33bbb';

      // Mock User Profile
      final Map<String, dynamic> debugUser = {
        'shp_user_id': '4d99938a-78de-4b49-92ea-91d70cef675f',
        'name': 'LEONG GAO CHONG',
        'email': 'admin@debug.com',
        'phone': '167618273',
      };

      // 2. Use fetched shop_id if available, otherwise use hardcoded fallback
      final String actualShopId =
          _shelfDetails?['shop_id']?.toString() ?? debugShopId;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEBUG: Unlocking Shop: $actualShopId...')),
        );
      }

      // 3. Trigger IoT Unlock Directly
      final String sessionUuid = const Uuid().v4();

      await _apiService.awsRemoteStart(
        shopId: actualShopId,
        shelfId: widget.shelfId, // or use debugShelfId if testing specifically
        sessionId: sessionUuid,
        customerId: debugUser['shp_user_id'],
      );

      setState(() => _isMonitoring = true);

      // 4. Navigate to Shopping Screen
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ShoppingScreen(
            shelfId: widget.shelfId,
            userName: debugUser['name'],
            shelfName: _shelfDetails?['shelf_name'] ?? 'Shelf 1',
            shopId: actualShopId,
            customerId: debugUser['shp_user_id'],
            userEmail: debugUser['email'],
            userPhone: debugUser['phone'],
          ),
        ),
      );
    } catch (e) {
      _showError('Debug Error: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }
  //TEST ONLY
  //TEST ONLY
  //TEST ONLY
  //TEST ONLY
  //TEST ONLY
}

// --- MODIFIED: _ShelfInfoHeader to display Shop Name ---
class _ShelfInfoHeader extends StatelessWidget {
  final String shopName;
  final String shelfName;
  final String halalStatus;
  final bool isHalal;

  const _ShelfInfoHeader({
    required this.shopName,
    required this.shelfName,
    required this.halalStatus,
    required this.isHalal,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isHalal ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shelfName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            shopName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHalal ? Icons.verified : Icons.no_food,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  halalStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        color: accentColor.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final bool isHalal;

  const _InstructionCard({required this.isHalal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_moon_outlined,
                color: isHalal ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'Identity Check',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick face verification keeps the shelf secure and personalized '
            'for you. It takes less than 10 seconds.',
            style: TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
