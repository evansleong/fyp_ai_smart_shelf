import 'package:flutter/material.dart';
import 'dart:async';
import '../core/model/product_model.dart'; // 👈 IMPORT
import '../core/services/api_service.dart'; // 👈 IMPORT
import '../core/model/cart_model.dart';

class ShoppingScreen extends StatefulWidget {
  final String shelfId;
  final String userName;
  final String shelfName; // This is passed from the previous screen
  final String shopId;
  final String? customerId;

  const ShoppingScreen({
    super.key,
    required this.shelfId,
    required this.userName,
    required this.shelfName,
    required this.shopId,
    this.customerId,
  });

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  // --- Service ---
  final ApiService _apiService = ApiService(); // 👈 USE

  // --- State ---
  bool _isLoading = true;
  List<Product> _products = [];
  String? _errorMessage;
  late String _apiShelfName;
  String _shelfStatus = '';
  Cart? _cart;
  bool _cartLoading = true;
  String? _cartError;
  Timer? _cartTimer;

  Future<void> _triggerAgain() async {
    try {
      await _apiService.awsRemoteStart(
        shopId: widget.shopId,
        shelfId: widget.shelfId,
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
          _cartError = null;
          _cartLoading = false;
        });
      } else {
        setState(() {
          _cartError = (body['message'] ?? 'Failed to load cart').toString();
          _cartLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cartError = e.toString();
        _cartLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _apiShelfName = widget.shelfName;
    _fetchShelfProducts();
    if (widget.customerId != null && widget.customerId!.isNotEmpty) {
      _fetchCart();
      _cartTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchCart());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: _buildBody(),
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
              child: Text(
                'This shelf is currently empty.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          )
        else
          // --- MODIFIED: Product list is now in an Expanded widget ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0), // Add padding to list
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior:
                      Clip.antiAlias, // Ensures image corners are rounded
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    // --- MODIFIED: Added product image ---
                    leading: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              product.imageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              // Error handling for broken images
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
                    // --- END MODIFIED ---
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // --- MODIFIED: Show shelf-specific stock from 'quantity' ---
                    subtitle: Text('Stock on shelf: ${product.stock}'),
                    // --- END MODIFIED ---
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
          Column(
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildCartSection(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCartSection() {
    if (_cartLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Loading cart...'),
      );
    }
    if (_cartError != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _cartError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_cart == null || _cart!.items.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Your cart is empty'),
      );
    }

    // Build a lookup for product metadata to enrich cart items with names/prices
    final Map<String, Product> productById = {
      for (final p in _products) p.id: p,
    };

    // Compute display total using enriched prices when available
    final double displayTotal = _cart!.items.fold(0.0, (sum, it) {
      final p = productById[it.productId];
      final price = p?.price ?? it.price;
      return sum + price * it.quantity;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Cart',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._cart!.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (productById[item.productId]?.name ?? item.name),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.quantity} x RM ${(productById[item.productId]?.price ?? item.price).toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'RM ${displayTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
      ],
    );
  }
}
