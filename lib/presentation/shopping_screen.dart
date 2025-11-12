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

  Future<void> _triggerAgain() async {
    try {
      await _apiService.awsRemoteStart(
        shopId: widget.shopId,
        shelfId: widget.shelfId,
        customerId: widget.customerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shelf opened - Monitoring started')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trigger failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _cartTimer?.cancel();
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
      webSocketService.connect(customerId: widget.customerId!, shopId: widget.shopId);
      // Listen for cart updates
      _wsUnsubs.add(
        webSocketService.on('message', (dynamic message) {
          try {
            if (message is Map && message['type'] == 'cart_updated') {
              final data = message['data'];
              if (mounted && data is Map<String, dynamic>) {
                setState(() {
                  _cart = Cart.fromJson(data);
                });
              }
            }
          } catch (_) {}
        }),
      );
      // Optional: react to disconnects if you want UI feedback later
      _wsUnsubs.add(webSocketService.on('disconnect', (_) {}));
      _wsUnsubs.add(webSocketService.on('connect', (_) {}));
    }
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
        _filteredProducts = _products.where((p) => p.name.toLowerCase().contains(q)).toList();
      }
    });
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
              content: const Text('You will stop detection and end your shopping session.'),
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
            await _apiService.endSession(shopId: widget.shopId, shelfId: widget.shelfId);
          } catch (_) {}
          // Explicitly disconnect WebSocket when exiting the shelf
          try {
            webSocketService.send({
              'action': 'unsubscribe',
              'customer_id': widget.customerId,
              'shop_id': widget.shopId,
              'shelf_id': widget.shelfId,
            });
            // Give the socket a brief moment to flush the message
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
        appBar: AppBar(
          // --- MODIFIED: Use the shelf name fetched from the API ---
          title: Text(_apiShelfName),
          // --- END MODIFIED ---
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  'Hi, ${widget.userName}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Trigger Again',
              icon: const Icon(Icons.replay_circle_filled_outlined),
              onPressed: _triggerAgain,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search items on this shelf',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _buildBody(),
        floatingActionButton: (_cart != null && _cart!.items.isNotEmpty)
            ? Builder(
                builder: (context) {
                  // compute display total similar to _buildCartSection
                  final Map<String, Product> productById = {
                    for (final p in _products) p.id: p,
                  };
                  final double computedTotal = _cart!.items.fold(0.0, (sum, it) {
                    final p = productById[it.productId];
                    final price = p?.price ?? it.price;
                    return sum + price * it.quantity;
                  });
                  final double displayTotal = (_cart!.total > 0) ? _cart!.total : computedTotal;
                  return FloatingActionButton.extended(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: false,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (ctx) {
                          final items = _cart!.items;
                          return SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shopping_cart_outlined),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Cart Summary',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'RM ${displayTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...items.take(3).map((it) {
                                    final p = productById[it.productId];
                                    final name = p?.name ?? it.name;
                                    final price = p?.price ?? it.price;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                                          Text('x${it.quantity} • RM ${(price * it.quantity).toStringAsFixed(2)}'),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  if (items.length > 3)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('+ ${items.length - 3} more item(s)', style: const TextStyle(color: Colors.grey)),
                                    ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx); // close sheet
                                        Navigator.push(
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
                                      },
                                      icon: const Icon(Icons.arrow_forward_rounded),
                                      label: const Text('Go to Cart'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: Text('Cart \u2022 RM ${displayTotal.toStringAsFixed(2)}'),
                  );
                },
              )
            : null,
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

    // --- NEW: Show shelf status (e.g., "Non-Halal") ---
    final statusColor = _shelfStatus.toLowerCase() == 'non-halal'
        ? Colors.red.shade700
        : Colors.green.shade700;
    // --- END NEW ---

    return Column(
      children: [
        // --- NEW: Shelf Status Header ---
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Shelf Status: $_shelfStatus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        // --- END NEW ---

        if (_products.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'This shelf is currently empty.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
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
                  const Icon(Icons.search_off, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No items match "${_searchCtrl.text}"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _applyFilter();
                    },
                    child: const Text('Clear search'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior:
                      Clip.antiAlias,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              product.imageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image,
                                    size: 32, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood,
                                size: 32, color: Colors.grey),
                          ),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Stock on shelf: ${product.stock}'),
                    trailing: Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
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
