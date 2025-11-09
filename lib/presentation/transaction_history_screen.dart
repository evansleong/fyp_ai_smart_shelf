import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import '../core/services/api_service.dart';
import '../core/services/location_service.dart';
import 'transaction_details_screen.dart';
import '../core/widgets/camera_screen.dart';
import 'shelf_verification_screen.dart';
import 'profile_screen.dart'; // <-- 1. IMPORT YOUR NEW SCREEN

class TransactionHistoryScreen extends StatefulWidget {
  final String shpUserId;

  const TransactionHistoryScreen({
    super.key,
    required this.shpUserId,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  late Future<List<dynamic>> _transactionsFuture;

  // --- 2. ADD STATE FOR USER PROFILE ---
  Map<String, dynamic>? _userProfileData;
  bool _isLoadingProfile = true;
  bool _isFindingNearby = false;
  // --- END ---

  @override
  void initState() {
    super.initState();
    // Load both transactions and user profile when the screen opens
    _transactionsFuture = _apiService.getCustomerOrders(widget.shpUserId);
    _loadUserProfile(); // <-- 3. CALL NEW FUNCTION
  }

  // --- 4. ADD NEW FUNCTION TO FETCH USER DATA ---
  Future<void> _loadUserProfile() async {
    try {
      final user =
          await _apiService.getShopperInfo(shpUserId: widget.shpUserId);
      if (mounted) {
        setState(() {
          _userProfileData = user;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        // Show a non-blocking error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load user profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating, // Use floating behavior
            margin:
                const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
      }
    }
  }
  // --- END ---

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shp_user_id');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _scanAndNavigateToShelf() async {
    final qrCodeResult = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          scanMode: CameraScanMode.qrCode,
        ),
      ),
    );

    if (qrCodeResult != null && context.mounted) {
      try {
        final shelf = await _apiService.awsShelfLookup(qrCodeResult);
        final String shopId = (shelf['shop_id'] ?? '').toString();
        if (shopId.isEmpty) {
          throw Exception('Shelf lookup missing shop_id');
        }
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShelfVerificationScreen(
              shelfId: qrCodeResult,
            ),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open shelf: $e'),
              backgroundColor: Colors.red,
              // --- ADDED: Fix for snackbar pushing nav bar ---
              behavior: SnackBarBehavior.floating,
              margin:
                  const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              // --- END ---
            ),
          );
        }
      }
    }
  }

  Future<void> _findAndShowNearbyShelves() async {
    if (_isFindingNearby) return; // Prevent double-taps

    setState(() {
      _isFindingNearby = true;
    });

    // Show a loading snackbar
    final messenger = ScaffoldMessenger.of(context);
    final loadingSnackbar = SnackBar(
      content: Row(
        children: const [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(width: 16),
          Text('Finding nearby shelves...'),
        ],
      ),
      duration: const Duration(minutes: 1), // Will be hidden manually
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    );
    messenger.showSnackBar(loadingSnackbar);

    try {
      // 1. Get location
      final Position position = await _locationService.getCurrentLocation();

      // 2. Call API
      final List<dynamic> nearbyShops =
          await _apiService.findNearbyShelves(
        position.latitude,
        position.longitude,
      );

      messenger.hideCurrentSnackBar(); // Hide loading

      if (!mounted) return;

      if (nearbyShops.isEmpty) {
        // Show a "not found" snackbar
        messenger.showSnackBar(
          SnackBar(
            content: const Text('No nearby shelves found.'),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
            margin:
                const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
          ),
        );
        return;
      }

      // 3. Show results in a bottom sheet
      _showNearbyShelvesDialog(nearbyShops);
    } catch (e) {
      messenger.hideCurrentSnackBar(); // Hide loading
      if (mounted) {
        // Show error snackbar
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error finding shelves: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin:
                const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFindingNearby = false;
        });
      }
    }
  }

  void _showNearbyShelvesDialog(List<dynamic> shops) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow sheet to be taller
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Use a stateful builder to manage loading state inside the sheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isVerifyingShelf = false;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5, // Start at 50% height
              minChildSize: 0.3,
              maxChildSize: 0.8, // Allow up to 80%
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // --- Handle Bar ---
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    // --- Title ---
                    Text(
                      'Nearby Shelves',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    // --- Scrollable List ---
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: shops.length,
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          final shelves =
                              shop['shelves'] as List<dynamic>? ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Shop Header ---
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: Text(
                                  "${shop['shop_name']} (${shop['distance_km']} km)",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              // --- List of Shelves for this shop ---
                              ...shelves.map((shelf) {
                                final shelfId =
                                    shelf['shelf_id']?.toString() ?? '';
                                final shelfName =
                                    shelf['shelf_name']?.toString() ??
                                        'Unnamed Shelf';
                                final shelfLocation =
                                    shelf['shelf_location']?.toString() ??
                                        'No location';

                                return ListTile(
                                  leading: const Icon(Icons.shelves),
                                  title: Text(shelfName),
                                  subtitle: Text(shelfLocation),
                                  trailing: (isVerifyingShelf)
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 3))
                                      : const Icon(Icons.chevron_right),
                                  onTap: (isVerifyingShelf || shelfId.isEmpty)
                                      ? null
                                      : () async {
                                          // --- Shelf Tap Handler ---
                                          setModalState(() {
                                            isVerifyingShelf = true;
                                          });
                                          try {
                                            // Verify shelf exists (mirroring QR flow)
                                            await _apiService
                                                .awsShelfLookup(shelfId);

                                            if (!mounted) return;
                                            Navigator.of(context)
                                                .pop(); // Close bottom sheet
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ShelfVerificationScreen(
                                                  shelfId: shelfId,
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            Navigator.of(context)
                                                .pop(); // Close bottom sheet
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed to open shelf: $e'),
                                                backgroundColor: Colors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(
                                                    bottom: 80.0,
                                                    left: 16.0,
                                                    right: 16.0),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0)),
                                              ),
                                            );
                                          } finally {
                                            // No need to reset state, sheet is closing
                                          }
                                        },
                                );
                              }).toList(),
                              if (index < shops.length - 1)
                                const Divider(indent: 16, endIndent: 16),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          // --- 7. ADDED: Nearby Shelves Button ---
          IconButton(
            icon: Icon(_isFindingNearby
                ? Icons.location_searching // Show loading icon
                : Icons.location_on_outlined),
            tooltip: 'Nearby Shelves',
            onPressed: _isFindingNearby ? null : _findAndShowNearbyShelves,
          ),
          // --- END ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          // ... (Your FutureBuilder logic is unchanged)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load history:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no transaction history yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final transactions = snapshot.data!;
          final List<dynamic> groupedItems = [];
          String? currentDateHeader;

          for (final transaction in transactions) {
            final date = transaction['date'] ?? 'Unknown Date';
            if (date != currentDateHeader) {
              currentDateHeader = date;
              groupedItems.add(date); // Add the date header
            }
            groupedItems.add(transaction); // Add the transaction item
          }

          return ListView.builder(
            itemCount: groupedItems.length,
            padding: const EdgeInsets.only(bottom: 80.0),
            itemBuilder: (context, index) {
              final item = groupedItems[index];

              // --- Date Header ---
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                  ),
                );
              }

              // --- Transaction ListTile ---
              if (item is Map<String, dynamic>) {
                final transaction = item;
                final imageUrl = transaction['imageUrl'] as String?;
                final paymentMethod = transaction['payment_method'] ?? 'N/A';
                final time = transaction['time'] ?? 'No Time';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: (imageUrl != null)
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Colors.grey),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.inventory_2_outlined,
                                    color: Colors.grey),
                              ),
                      ),
                    ),
                    title: Text(
                      transaction['details'] ?? 'No Details',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$paymentMethod • $time',
                      style:
                          TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                    isThreeLine: false,
                    trailing: Text(
                      '- RM ${transaction['amount'] ?? '0.00'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailsScreen(
                            transaction: transaction,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
              return Container();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _scanAndNavigateToShelf,
        child: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        elevation: 8.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavButton(
              icon: Icons.history,
              label: 'History',
              onPressed: () {
                print("Already on History screen");
              },
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 48),

            // --- 5. MODIFY THE "PROFILE" BUTTON ---
            _buildNavButton(
              icon: Icons.person_outline,
              label: 'Profile',
              // Disable button while loading or if data failed to load
              onPressed: (_isLoadingProfile || _userProfileData == null)
                  ? null // This disables the InkWell
                  : () {
                      // Navigate to ProfileScreen with the fetched data
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(user: _userProfileData!),
                        ),
                      );
                    },
              // Show a faded color if disabled
              color: (_isLoadingProfile || _userProfileData == null)
                  ? Colors.grey.shade400
                  : null,
            ),
            // --- END ---
          ],
        ),
      ),
    );
  }

  // --- (Helper widget is unchanged) ---
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed, // Changed to allow null
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color ?? Colors.grey.shade700, size: 28.0),
            const SizedBox(height: 2.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.grey.shade700,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
