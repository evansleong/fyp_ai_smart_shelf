import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'welcome_screen.dart';
import '../core/services/api_service.dart';
import 'transaction_history_screen.dart';
import '../core/widgets/camera_screen.dart';
import 'shelf_verification_screen.dart';
import 'profile_screen.dart';
import 'search_shelves_screen.dart';
import 'register_details_screen.dart';

// RouteObserver to detect when routes become active
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  final String shpUserId;

  const HomeScreen({
    super.key,
    required this.shpUserId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final ApiService _apiService = ApiService();

  int _pageIndex = 0;
  late final List<Widget> _pages;
  final GlobalKey<_HomeScreenBodyState> _homeScreenBodyKey = GlobalKey<_HomeScreenBodyState>();

  Map<String, dynamic>? _userProfileData;
  bool _isLoadingProfile = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    // Called when the current route has been pushed
    _refreshHomeData();
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped off, and this route shows up
    _refreshHomeData();
  }

  void _refreshHomeData() {
    // Refresh transaction overview when home screen becomes visible
    if (_pageIndex == 0) {
      _homeScreenBodyKey.currentState?.refreshTransactionOverview();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    _pages = [
      _HomeScreenBody(
        key: _homeScreenBodyKey,
        userProfileData: _userProfileData,
        isLoadingProfile: _isLoadingProfile,
        shpUserId: widget.shpUserId,
        // customerId is null at first, will be updated by _loadUserProfile
        customerId: _userProfileData?['shp_user_id'],
      ),
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
          // Rebuild _HomeScreenBody with the loaded customerId
          _pages[0] = _HomeScreenBody(
            key: _homeScreenBodyKey,
            userProfileData: _userProfileData,
            isLoadingProfile: _isLoadingProfile,
            shpUserId: widget.shpUserId,
            customerId: _userProfileData?['shp_user_id'],
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          // Rebuild _HomeScreenBody even on error (customerId will be null)
          _pages[0] = _HomeScreenBody(
            key: _homeScreenBodyKey,
            userProfileData: _userProfileData,
            isLoadingProfile: _isLoadingProfile,
            shpUserId: widget.shpUserId,
            customerId: _userProfileData?['shp_user_id'],
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShelfVerificationScreen(
              shelfId: qrCodeResult,
            ),
          ),
        );
        // Refresh when returning from shopping
        _refreshHomeData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          _pageIndex == 0 ? 'Home' : 'Search Shelves',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // Temporary debug button for RegisterDetailsScreen
          IconButton(
            icon: const Icon(Icons.app_registration, color: Colors.orange),
            tooltip: 'Test Register Details (Debug)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RegisterDetailsScreen(),
                ),
              );
            },
          ),
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
      body: IndexedStack(
        index: _pageIndex,
        children: _pages,
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
              icon: Icons.home,
              label: 'Home',
              onPressed: () {
                setState(() {
                  _pageIndex = 0;
                });
                // Refresh transaction overview when switching to home tab
                _homeScreenBodyKey.currentState?.refreshTransactionOverview();
              },
              color: _pageIndex == 0
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const SizedBox(width: 48),
            _buildNavButton(
              icon: Icons.shelves,
              label: 'Shelf',
              onPressed: () {
                setState(() {
                  _pageIndex = 1;
                });
              },
              color: _pageIndex == 1
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

// --- HOME SCREEN BODY (NOW STATEFUL) ---
class _HomeScreenBody extends StatefulWidget {
  final Map<String, dynamic>? userProfileData;
  final bool isLoadingProfile;
  final String shpUserId;
  final String? customerId;

  const _HomeScreenBody({
    super.key,
    required this.userProfileData,
    required this.isLoadingProfile,
    required this.shpUserId,
    required this.customerId,
  });

  @override
  State<_HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<_HomeScreenBody> {
  final ApiService _apiService = ApiService();

  // State for transaction overview
  bool _isLoadingTransactions = true;
  double _totalSpent = 0.0; // Total after discount (what user actually paid)
  List<Map<String, dynamic>> _categoryChartData = [];
  String? _transactionError;
  
  // State for AI insights
  Map<String, dynamic>? _aiInsights;

  // Chart colors
  final List<Color> _chartColors = const [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFD93D),
    Color(0xFFA8E6CF),
    Color(0xFF45B7D1),
    Color(0xFFF7A399),
  ];

  @override
  void initState() {
    super.initState();
    // Fetch data immediately if customerId is already available
    if (widget.customerId != null) {
      _fetchTransactionOverview();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When customerId becomes available (after profile loads), fetch data.
    if (widget.customerId != null && oldWidget.customerId == null) {
      _fetchTransactionOverview();
    }
  }

  /// Public method to refresh transaction overview
  void refreshTransactionOverview() {
    if (widget.customerId != null) {
      _fetchTransactionOverview();
    }
  }

  Future<void> _fetchTransactionOverview() async {
    if (widget.customerId == null) {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
          _transactionError = 'Could not load customer details.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingTransactions = true;
        _transactionError = null;
      });
    }

    try {
      // use KAH YUNG data first
      //const String testCustomerId = "9a3e4a12-0652-441d-959b-584bd07ed05a";
      // 1. Fetch Orders
      final List<dynamic> orders =
          //await _apiService.getCustomerOrders(testCustomerId);
      await _apiService.getCustomerOrders(widget.customerId!);

      // 2. Process Orders
      final Map<String, double> categorySpend = {};
      double subtotalSpend = 0.0; // For percentage calculations (before discount)
      double totalSpendAfterDiscount = 0.0; // For display (after discount, what user actually paid)

      if (orders.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingTransactions = false;
            _categoryChartData = [];
            _totalSpent = 0.0;
          });
        }
        return;
      }

    for (var order in orders) {
      final List<dynamic> items = order['items'] ?? [];
      final summary = order['summary'];

      // Helper to parse summary value (handles DynamoDB format)
      double? parseSummaryValue(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is Map && value.containsKey('N')) {
          return double.tryParse(value['N'].toString());
        }
        if (value is String) return double.tryParse(value);
        return null;
      }

      // Get subtotal and total_price from summary
      double? orderSubtotal;
      double? orderTotalPrice;
      if (summary != null) {
        if (summary['subtotal'] != null) {
          orderSubtotal = parseSummaryValue(summary['subtotal']);
        }
        if (summary['total_price'] != null) {
          orderTotalPrice = parseSummaryValue(summary['total_price']);
        }
      }

      // Calculate category spend from items
      double orderItemsTotal = 0.0;
      for (var item in items) {
        final String category = item['category'] ?? 'Others';
        final double price = (item['unit_price'] ?? 0.0).toDouble();
        final int quantity = (item['quantity'] ?? 0).toInt();
        final double itemTotal = price * quantity;
        orderItemsTotal += itemTotal;

        categorySpend.update(category, (value) => value + itemTotal,
            ifAbsent: () => itemTotal);
      }

      // Use subtotal from summary if available (for percentage calculations)
      // This ensures percentages add up to 100%
      final orderSubtotalForCalc = orderSubtotal ?? orderItemsTotal;
      subtotalSpend += orderSubtotalForCalc;
      
      // Track total price (after discount) for display
      final orderTotalForDisplay = orderTotalPrice ?? orderSubtotalForCalc;
      totalSpendAfterDiscount += orderTotalForDisplay;
    }

      // Fallback: If subtotalSpend is 0, calculate from categorySpend
      if (subtotalSpend == 0.0 && categorySpend.isNotEmpty) {
        subtotalSpend = categorySpend.values.reduce((a, b) => a + b);
        // If we don't have totalSpendAfterDiscount, use subtotalSpend
        if (totalSpendAfterDiscount == 0.0) {
          totalSpendAfterDiscount = subtotalSpend;
        }
      }

      if (subtotalSpend == 0.0) {
        if (mounted) {
          setState(() {
            _isLoadingTransactions = false;
            _categoryChartData = [];
            _totalSpent = 0.0;
          });
        }
        return;
      }

      // 3. Convert to Chart Data
      int colorIndex = 0;
      final List<Map<String, dynamic>> chartData = [];

      // Sort by spend, descending
      final sortedCategories = categorySpend.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedCategories) {
        chartData.add({
          'category': entry.key,
          'percentage': (entry.value / subtotalSpend) * 100,
          'color': _chartColors[colorIndex % _chartColors.length],
        });
        colorIndex++;
      }

      // 4. Calculate AI Insights (use totalSpendAfterDiscount for insights)
      _calculateAIInsights(orders, categorySpend, totalSpendAfterDiscount);

      // 5. Set State
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
          _totalSpent = totalSpendAfterDiscount; // Display total after discount
          _categoryChartData = chartData;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
          _transactionError = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFF1F5F9),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(context),
            const SizedBox(height: 24),

            // Transaction Overview Card
            _buildTransactionOverviewCard(context),
            const SizedBox(height: 20),

            // AI Insights Section
            _buildAIInsightsSection(context),
            const SizedBox(height: 80), // Bottom padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.isLoadingProfile
                          ? 'Welcome!'
                          : 'Welcome back,',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isLoadingProfile
                      ? 'User'
                      : '${widget.userProfileData?['name'] ?? 'User'}!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ready to shop today?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _AnimatedWavingHand(
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionOverviewCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and View History Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overview',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                    letterSpacing: -0.3,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 50,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // View History Button
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionHistoryScreen(
                            shpUserId: widget.shpUserId,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.history,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      'View All',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Chart and Legend - Now dynamic
            if (_isLoadingTransactions)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_transactionError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Text(
                    'Error: $_transactionError',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_categoryChartData.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text('No transaction history for this month.'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 360;

                  if (isSmallScreen) {
                    // Stack vertically on small screens
                    return Column(
                      children: [
                        _buildDonutChart(_categoryChartData),
                        const SizedBox(height: 20),
                        _buildLegend(_categoryChartData, context),
                      ],
                    );
                  } else {
                    // Side by side on larger screens
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildDonutChart(_categoryChartData),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _buildLegend(_categoryChartData, context)),
                      ],
                    );
                  }
                },
              ),
            const SizedBox(height: 16),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Based on purchase history',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(List<Map<String, dynamic>> chartData) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 70,
                sections: chartData.map((data) {
                  return PieChartSectionData(
                    color: data['color'] as Color,
                    value: data['percentage'] as double,
                    title: '',
                    radius: 28,
                  );
                }).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Spend',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${_totalSpent.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(
      List<Map<String, dynamic>> chartData, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: chartData.map((data) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (data['color'] as Color).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: data['color'] as Color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (data['color'] as Color).withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['category'] as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (data['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(data['percentage'] as double).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: data['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _calculateAIInsights(List<dynamic> orders, Map<String, double> categorySpend, double totalSpend) {
    if (orders.isEmpty) {
      _aiInsights = null;
      return;
    }

    final Map<String, int> dayOfWeekCount = {};
    final Map<String, int> shopCount = {};
    String? topCategory;
    double topCategorySpend = 0.0;
    int totalTransactions = orders.length;
    double avgTransactionValue = totalSpend / totalTransactions;

    for (var entry in categorySpend.entries) {
      if (entry.value > topCategorySpend) {
        topCategorySpend = entry.value;
        topCategory = entry.key;
      }
    }

    for (var order in orders) {
      final dateStr = order['date'] ?? '';
      final shopName = order['shop_name'] ?? 
                       order['shopName'] ?? 
                       order['details'] ?? 
                       '';
      
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          final dayName = _getDayName(date.weekday);
          dayOfWeekCount.update(dayName, (value) => value + 1, ifAbsent: () => 1);
        } catch (e) {
          // Skip invalid dates
        }
      }
      
      if (shopName.isNotEmpty && 
          shopName.toLowerCase() != 'unknown shop' && 
          shopName.toLowerCase() != 'unknown') {
        shopCount.update(shopName, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    String? favoriteDay;
    int maxDayCount = 0;
    for (var entry in dayOfWeekCount.entries) {
      if (entry.value > maxDayCount) {
        maxDayCount = entry.value;
        favoriteDay = entry.key;
      }
    }

    String? favoriteShop;
    int maxShopCount = 0;
    for (var entry in shopCount.entries) {
      if (entry.value > maxShopCount) {
        maxShopCount = entry.value;
        favoriteShop = entry.key;
      }
    }

    _aiInsights = {
      'topCategory': topCategory ?? 'N/A',
      'topCategoryPercentage': totalSpend > 0 ? (topCategorySpend / totalSpend * 100) : 0.0,
      'favoriteDay': favoriteDay,
      'favoriteShop': favoriteShop,
      'totalTransactions': totalTransactions,
      'avgTransactionValue': avgTransactionValue,
      'totalSpend': totalSpend,
    };
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  Widget _buildAIInsightsSection(BuildContext context) {
    if (_isLoadingTransactions) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_transactionError != null || _aiInsights == null) {
      return const SizedBox.shrink();
    }

    final insights = _aiInsights!;
    final topCategory = insights['topCategory'] as String?;
    final favoriteDay = insights['favoriteDay'] as String?;
    final totalTransactions = insights['totalTransactions'] as int;
    final avgTransaction = insights['avgTransactionValue'] as double;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1),
                        const Color(0xFF6366F1).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Insights',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 50,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF6366F1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInsightCard(
              icon: Icons.category_outlined,
              title: 'Favorite Category',
              value: topCategory ?? 'N/A',
              subtitle: 'Most purchased category',
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 12),
            if (favoriteDay != null)
              _buildInsightCard(
                icon: Icons.calendar_today_outlined,
                title: 'Shopping Pattern',
                value: 'Usually shops on $favoriteDay',
                subtitle: 'Based on your history',
                color: const Color(0xFF10B981),
              ),
            if (favoriteDay != null) const SizedBox(height: 12),
            _buildInsightCard(
              icon: Icons.trending_up_outlined,
              title: 'Shopping Stats',
              value: '$totalTransactions transactions',
              subtitle: 'Avg: RM ${avgTransaction.toStringAsFixed(2)} per visit',
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
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

// Custom Auto-Scroll Carousel Widget
class _AutoScrollCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> products;

  const _AutoScrollCarousel({required this.products});

  @override
  State<_AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<_AutoScrollCarousel> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.5,
      initialPage: 0,
    );

    if (widget.products.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_currentPage < widget.products.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }

        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.products.isNotEmpty) {
      _timer.cancel();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No recommendations available.')),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(widget.products[index], context);
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.products.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: index == _currentPage % widget.products.length ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: index == _currentPage % widget.products.length
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, BuildContext context) {
    return Container(
      width: 170,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image (placeholder with emoji)
          Container(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Center(
              child: Text(
                product['emoji'] as String,
                style: const TextStyle(fontSize: 56),
              ),
            ),
          ),
          // Product details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] as String,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          product['tagline'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

// Animated Waving Hand Widget
class _AnimatedWavingHand extends StatefulWidget {
  final Color color;

  const _AnimatedWavingHand({
    required this.color,
  });

  @override
  State<_AnimatedWavingHand> createState() => _AnimatedWavingHandState();
}

class _AnimatedWavingHandState extends State<_AnimatedWavingHand>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create a repeating animation that goes from -20 to 20 degrees
    _rotationAnimation = Tween<double>(
      begin: -0.35, // -20 degrees in radians
      end: 0.35,    // 20 degrees in radians
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Repeat the animation
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            alignment: Alignment.bottomCenter,
            child: Icon(
              Icons.waving_hand,
              size: 32,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}
