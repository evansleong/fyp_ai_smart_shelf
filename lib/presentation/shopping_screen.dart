import 'package:flutter/material.dart';
import 'dart:async';
import '../core/model/product_model.dart';
import '../core/services/api_service.dart';
import '../core/model/cart_model.dart';
import 'cart_screen.dart';
import '../core/services/websocket_service.dart';

class ShoppingScreen extends StatefulWidget {
  final String shelfId;
  final String userName;
  final String shelfName;
  final String shopId;
  final String? customerId;
  final String? userEmail;
  final String? userPhone;

  const ShoppingScreen({
    super.key,
    required this.shelfId,
    required this.userName,
    required this.shelfName,
    required this.shopId,
    this.customerId,
    this.userEmail,
    this.userPhone,
  });

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  // --- Service ---
  final ApiService _apiService = ApiService(); //

  // --- State ---
  bool _isLoading = true;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String? _errorMessage;
  late String _apiShelfName;
  String _shelfStatus = '';
  Cart? _cart;
  Timer? _cartTimer;
  final List<Function()> _wsUnsubs = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _cartTimer?.cancel();
    _sessionCheckTimer?.cancel();
    for (final unsub in _wsUnsubs) {
      try {
        unsub();
      } catch (_) {}
    }
    webSocketService.disconnect();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCart() async {
    try {
      final body = await _apiService.getCustomerCart(
        customerId: widget.customerId!,
        shopId: widget.shopId,
      );
      if (!mounted) return;
      if (body['success'] == true && body['cart'] is Map<String, dynamic>) {
        setState(() {
          _cart = Cart.fromJson(body['cart'] as Map<String, dynamic>);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {});
    }
  }

  Timer? _sessionCheckTimer;

  @override
  void initState() {
    super.initState();
    _apiShelfName = widget.shelfName;
    _fetchShelfProducts();
    _searchCtrl.addListener(_applyFilter);
    if (widget.customerId != null && widget.customerId!.isNotEmpty) {
      // Initial load via REST for baseline state
      _fetchCart();
      // Connect WebSocket for live updates
      webSocketService.connect(
          customerId: widget.customerId!, shopId: widget.shopId);
      // Listen for cart updates
      _wsUnsubs.add(
        webSocketService.on('message', (dynamic message) {
          try {
            if (message is Map) {
              // Handle cart updates
              if (message['type'] == 'cart_updated') {
                final data = message['data'];
                if (mounted && data is Map<String, dynamic>) {
                  setState(() {
                    _cart = Cart.fromJson(data);
                  });
                  // Refresh products to update stock quantities in real-time
                  _fetchShelfProducts();
                }
              }
              // Handle session stop (forced end from Lambda)
              else if (message['type'] == 'session.stop' ||
                  message['type'] == 'session_stop') {
                _handleSessionEnded();
              }
            }
          } catch (_) {}
        }),
      );
      // Optional: react to disconnects if you want UI feedback later
      _wsUnsubs.add(webSocketService.on('disconnect', (_) {}));
      _wsUnsubs.add(webSocketService.on('connect', (_) {}));

      // Start periodic session check (fallback if WebSocket message fails)
      _startSessionCheck();
    }
  }

  void _startSessionCheck() {
    // Check session status every 5 seconds
    _sessionCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        // Check if session is still active
        final sessionStatus = await _apiService.checkSessionStatus(
          shopId: widget.shopId,
          shelfId: widget.shelfId,
        );

        // Debug: print what we received
        final status = sessionStatus?['status'];
        print('[SessionCheck] status=$status');

        // End session if no session exists or explicitly stopped
        // After Lambda fix: 'inactive' means no session, 'onHold' means paused
        if (status == 'inactive' || status == 'stopped' || status == 'ended') {
          print('[SessionCheck] Ending session due to status: $status');
          timer.cancel();
          _handleSessionEnded();
        }
      } catch (e) {
        // Don't end session on API errors - just log and continue polling
        print('[SessionCheck] API error (ignoring): $e');
      }
    });
  }

  void _handleSessionEnded() {
    if (!mounted) return;

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your shopping session has ended'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    // Clean up WebSocket
    try {
      webSocketService.send({
        'action': 'unsubscribe',
        'customer_id': widget.customerId,
        'shop_id': widget.shopId,
        'shelf_id': widget.shelfId,
      });
    } catch (_) {}

    try {
      webSocketService.disconnect();
    } catch (_) {}

    // Navigate back
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  // --- REFACTORED: Uses ApiService ---
  Future<void> _fetchShelfProducts() async {
    try {
      // 1. Call the service
      final responseData = await _apiService.fetchShelfProducts(widget.shelfId);

      // 2. Safety check
      if (responseData['products'] == null) {
        throw Exception('Received an invalid response from the server.');
      }

      // 3. Parse data
      final List<dynamic> productList = responseData['products'];
      final String apiShelfName = responseData['shelfName'] ?? widget.shelfName;
      final String shelfStatus = responseData['shelfStatus'] ?? '';

      // 4. Set state
      if (!mounted) return;
      setState(() {
        _products = productList.map((json) => Product.fromJson(json)).toList();
        _filteredProducts = List<Product>.from(_products);
        _apiShelfName = apiShelfName;
        _shelfStatus = shelfStatus;
        _isLoading = false;
      });
    } catch (e) {
      // 5. Handle errors
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredProducts = List<Product>.from(_products);
      } else {
        _filteredProducts =
            _products.where((p) => p.name.toLowerCase().contains(q)).toList();
      }
    });
  }

  void _showTheftSnackBar(int itemCount, String orderId) {
    if (!mounted) return;

    final message =
        '$itemCount item${itemCount > 1 ? 's' : ''} not returned. Marked as missing (Order: $orderId).';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items Not Returned',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('End session?'),
              content: const Text(
                  'You will stop detection and end your shopping session.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('End Session'),
                ),
              ],
            );
          },
        );
        if (shouldExit == true) {
          try {
            // Capture the response from endSession
            final response = await _apiService.endSession(
                shopId: widget.shopId, shelfId: widget.shelfId);

            // Check if theft was detected
            if (response != null && response['theft_detected'] == true) {
              final theftDetails = response['theft_details'];
              if (theftDetails != null) {
                _showTheftSnackBar(
                  theftDetails['total_items'] ?? 0,
                  theftDetails['order_id'] ?? 'UNKNOWN',
                );
              }
            }
          } catch (_) {}
          try {
            webSocketService.send({
              'action': 'unsubscribe',
              'customer_id': widget.customerId,
              'shop_id': widget.shopId,
              'shelf_id': widget.shelfId,
            });
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (_) {}
          try {
            webSocketService.disconnect();
          } catch (_) {}
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _apiShelfName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'Hi, ${widget.userName}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            // Trigger button removed as requested
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),
        ),
        body: _buildBody(),
        floatingActionButton: (_cart != null && _cart!.items.isNotEmpty)
            ? Builder(
                builder: (context) {
                  final Map<String, Product> productById = {
                    for (final p in _products) p.id: p,
                  };
                  final double computedTotal =
                      _cart!.items.fold(0.0, (sum, it) {
                    final p = productById[it.productId];
                    final price = p?.price ?? it.price;
                    return sum + price * it.quantity;
                  });
                  final double displayTotal =
                      (_cart!.total > 0) ? _cart!.total : computedTotal;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    child: FloatingActionButton.extended(
                      backgroundColor: Colors.deepPurple,
                      elevation: 4,
                      onPressed: () async {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => _buildCartBottomSheet(
                              ctx, displayTotal, productById),
                        );
                      },
                      icon: const Icon(Icons.shopping_bag_outlined,
                          color: Colors.white),
                      label: Row(
                        children: [
                          Text('${_cart!.items.length} items',
                              style: const TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          Container(
                              width: 1, height: 16, color: Colors.white24),
                          const SizedBox(width: 8),
                          Text('RM ${displayTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildCartBottomSheet(
      BuildContext ctx, double displayTotal, Map<String, Product> productById) {
    final items = _cart!.items;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                'Cart Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'RM ${displayTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length > 3 ? 3 : items.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final it = items[index];
                final p = productById[it.productId];
                final name = p?.name ?? it.name;
                final price = p?.price ?? it.price;
                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${it.quantity}x',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            Text(name, style: const TextStyle(fontSize: 16))),
                    Text('RM ${(price * it.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                );
              },
            ),
          ),
          if (items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('+ ${items.length - 3} more item(s)',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx); // close sheet
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(
                      shopId: widget.shopId,
                      customerId: widget.customerId!,
                      shelfId: widget.shelfId,
                      userName: widget.userName,
                      shelfName: widget.shelfName,
                      userEmail: widget.userEmail,
                      userPhone: widget.userPhone,
                    ),
                  ),
                );
                // Refresh data when returning from Cart/Checkout
                if (mounted) {
                  _fetchShelfProducts();
                  _fetchCart();
                }
              },
              child: const Text('View Cart & Checkout',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final statusColor = _shelfStatus.toLowerCase() == 'non-halal'
        ? Colors.red.shade700
        : Colors.green.shade700;

    return Column(
      children: [
        if (_shelfStatus.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: statusColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _shelfStatus.toLowerCase() == 'non-halal'
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _shelfStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        if (_products.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Shelf is empty',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          )
        else if (_filteredProducts.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No items match "${_searchCtrl.text}"',
                      style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _applyFilter();
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65, // Taller cards
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (product.imageUrl != null)
                              Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade100,
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey.shade400),
                                ),
                              )
                            else
                              Container(
                                color: Colors.grey.shade100,
                                child: Icon(Icons.fastfood,
                                    size: 40, color: Colors.grey.shade400),
                              ),
                            if (product.stock <= 5)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${product.stock} left',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM ${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (widget.customerId != null && widget.customerId!.isNotEmpty)
          const SizedBox.shrink(),
      ],
    );
  }
}
