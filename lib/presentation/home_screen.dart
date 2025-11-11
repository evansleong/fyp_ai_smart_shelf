import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import '../core/services/api_service.dart';
import 'transaction_history_screen.dart'; 
import '../core/widgets/camera_screen.dart';
import 'shelf_verification_screen.dart';
import 'profile_screen.dart';
import 'search_shelves_screen.dart'; 

class HomeScreen extends StatefulWidget {
  final String shpUserId;

  const HomeScreen({
    super.key,
    required this.shpUserId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  // --- 1. STATE FOR TABS ---
  int _pageIndex = 0; // 0 = Home, 1 = Search
  late final List<Widget> _pages;
  // --- END ---

  Map<String, dynamic>? _userProfileData;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // --- 2. INITIALIZE THE PAGES FOR THE TABS ---
    _pages = [
      // Page 0: Home content
      _HomeScreenBody(
        userProfileData: _userProfileData,
        isLoadingProfile: _isLoadingProfile,
        shpUserId: widget.shpUserId,
      ),
      // Page 1: Search content
      const SearchShelvesScreen(),
    ];
  }

  Future<void> _loadUserProfile() async {
    try {
      final user =
          await _apiService.getShopperInfo(shpUserId: widget.shpUserId);
      if (mounted) {
        setState(() {
          _userProfileData = user;
          _isLoadingProfile = false;
          // --- 3. REBUILD _pages WITH USER DATA ---
          // This updates the _HomeScreenBody widget once data is loaded
          _pages[0] = _HomeScreenBody(
            userProfileData: _userProfileData,
            isLoadingProfile: _isLoadingProfile,
            shpUserId: widget.shpUserId,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _pages[0] = _HomeScreenBody(
            userProfileData: _userProfileData,
            isLoadingProfile: _isLoadingProfile,
            shpUserId: widget.shpUserId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load user profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
              behavior: SnackBarBehavior.floating,
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
  }
  // --- (End of helper functions) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // --- 4. DYNAMIC APP BAR TITLE ---
        title: Text(_pageIndex == 0 ? 'Home Screen' : 'Search Shelves'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: (_isLoadingProfile || _userProfileData == null)
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(user: _userProfileData!),
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      
      // --- 5. BODY IS NOW AN INDEXEDSTACK ---
      body: IndexedStack(
        index: _pageIndex,
        children: _pages,
      ),
      // --- END OF NEW BODY ---

      floatingActionButton: FloatingActionButton.large(
        onPressed: _scanAndNavigateToShelf,
        child: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // --- 6. UPDATED BottomAppBar LOGIC ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        elevation: 8.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // --- "Home" button ---
            _buildNavButton(
              icon: Icons.home,
              label: 'Home',
              onPressed: () {
                setState(() {
                  _pageIndex = 0; // Switch to Home tab
                });
              },
              color: _pageIndex == 0 // Active state
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const SizedBox(width: 48),

            // --- "Search" button ---
            _buildNavButton(
              icon: Icons.search,
              label: 'Search',
              onPressed: () {
                setState(() {
                  _pageIndex = 1; // Switch to Search tab
                });
              },
              color: _pageIndex == 1 // Active state
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
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

// --- 7. NEW WIDGET FOR HOME CONTENT ---
class _HomeScreenBody extends StatelessWidget {
  final Map<String, dynamic>? userProfileData;
  final bool isLoadingProfile;
  final String shpUserId;

  const _HomeScreenBody({
    required this.userProfileData,
    required this.isLoadingProfile,
    required this.shpUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLoadingProfile
                  ? 'Loading...'
                  : 'Welcome, ${userProfileData?['name'] ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ready to shop? Scan a QR code to begin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('View Transaction History'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TransactionHistoryScreen(
                      // Pass the test ID
                      shpUserId: "9a3e4a12-0652-441d-959b-584bd07ed05a",
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}