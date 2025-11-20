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

  int _pageIndex = 0;
  late final List<Widget> _pages;

  Map<String, dynamic>? _userProfileData;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    _pages = [
      _HomeScreenBody(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
  double _totalSpent = 0.0;
  List<Map<String, dynamic>> _categoryChartData = [];
  String? _transactionError;

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
      const String testCustomerId = "9a3e4a12-0652-441d-959b-584bd07ed05a";
      // 1. Fetch Orders
      final List<dynamic> orders =
          await _apiService.getCustomerOrders(testCustomerId);
      //await _apiService.getCustomerOrders(widget.customerId!);

      // 2. Process Orders
      final Map<String, double> categorySpend = {};
      double totalSpend = 0.0;

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

        // Use summary total if available, otherwise sum items
        final summary = order['summary'];
        if (summary != null && summary['total_price'] != null) {
          totalSpend += (summary['total_price'] as num).toDouble();
        }

        for (var item in items) {
          // **Assumption**: Lambda returns clean JSON with 'category',
          // 'unit_price', and 'quantity'.
          final String category = item['category'] ?? 'Others';
          final double price = (item['unit_price'] ?? 0.0).toDouble();
          final int quantity = (item['quantity'] ?? 0).toInt();
          final double itemTotal = price * quantity;

          categorySpend.update(category, (value) => value + itemTotal,
              ifAbsent: () => itemTotal);
        }
      }

      // Fallback: If totalSpend from summaries was 0, calculate from items
      if (totalSpend == 0.0 && categorySpend.isNotEmpty) {
        totalSpend = categorySpend.values.reduce((a, b) => a + b);
      }

      if (totalSpend == 0.0) {
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
          'percentage': (entry.value / totalSpend) * 100,
          'color': _chartColors[colorIndex % _chartColors.length],
        });
        colorIndex++;
      }

      // 4. Set State
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
          _totalSpent = totalSpend;
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
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(context),
            const SizedBox(height: 20),

            // Transaction Overview Card
            _buildTransactionOverviewCard(context),
            const SizedBox(height: 16),

            // Product Recommendations Carousel
            _buildRecommendationsCarousel(context),
            const SizedBox(height: 80), // Bottom padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isLoadingProfile
                ? 'Welcome!'
                : 'Welcome, ${widget.userProfileData?['name'] ?? 'User'}!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ready to shop today?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionOverviewCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and View History Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
                // View History Button
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionHistoryScreen(
                          // Pass shpUserId as the original code did
                          shpUserId: widget.shpUserId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Based on purchase history',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(List<Map<String, dynamic>> chartData) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius:70,
              sections: chartData.map((data) {
                return PieChartSectionData(
                  color: data['color'] as Color,
                  value: data['percentage'] as double,
                  title: '',
                  radius: 25,
                );
              }).toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Spend',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // Use the fetched total spend
                '\RM${_totalSpent.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(
      List<Map<String, dynamic>> chartData, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: chartData.map((data) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: data['color'] as Color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data['category'] as String,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(data['percentage'] as double).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendationsCarousel(BuildContext context) {
    // Mock product data
    final products = [
      {
        'name': 'Iced Latte',
        'tagline': 'Popular choice!',
        'emoji': '☕',
      },
      {
        'name': 'Chicken Wrap',
        'tagline': 'Healthy option',
        'emoji': '🥙',
      },
      {
        'name': 'Protein Bar',
        'tagline': 'Energy boost!',
        'emoji': '🍫',
      },
      {
        'name': 'Fresh Juice',
        'tagline': 'Vitamin rich',
        'emoji': '🧃',
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended for You',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _AutoScrollCarousel(products: products),
          ],
        ),
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
          height: 220,
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
            (index) => Container(
              width: index == _currentPage % widget.products.length ? 8 : 6,
              height: index == _currentPage % widget.products.length ? 8 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
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
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image (placeholder with emoji)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                product['emoji'] as String,
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
          // Product details
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] as String,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product['tagline'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
