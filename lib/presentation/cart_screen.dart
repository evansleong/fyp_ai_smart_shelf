import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/model/product_model.dart';
import '../core/model/cart_model.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final String shopId;
  final String customerId;
  final String shelfId;
  final String userName;
  final String shelfName;
  final String? userEmail;
  final String? userPhone;

  const CartScreen({
    super.key,
    required this.shopId,
    required this.customerId,
    required this.shelfId,
    required this.userName,
    required this.shelfName,
    this.userEmail,
    this.userPhone,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Cart? _cart;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cartBody = await _api.getCustomerCart(
        customerId: widget.customerId,
        shopId: widget.shopId,
      );
      final productsResp = await _api.fetchShelfProducts(widget.shelfId);
      if (!mounted) return;
      if (cartBody['success'] == true && cartBody['cart'] is Map<String, dynamic>) {
        setState(() {
          _cart = Cart.fromJson(cartBody['cart'] as Map<String, dynamic>);
          final List<dynamic> list = productsResp['products'] ?? [];
          _products = list.map((e) => Product.fromJson(e)).toList();
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = (cartBody['message'] ?? 'Failed to load cart').toString();
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_cart == null || _cart!.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.storefront),
                label: const Text('Browse shelf'),
              ),
            ],
          ),
        ),
      );
    }

    final Map<String, Product> byId = { for (final p in _products) p.id: p };
    final computedTotal = _cart!.items.fold<double>(0.0, (sum, it) {
      final p = byId[it.productId];
      final price = p?.price ?? it.price;
      return sum + price * it.quantity;
    });
    final displayTotal = (_cart!.total > 0) ? _cart!.total : computedTotal;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.shelfName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_cart!.items.length} item(s)', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Text('RM ${displayTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _cart!.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = _cart!.items[i];
              final p = byId[it.productId];
              final name = p?.name ?? it.name;
              final price = p?.price ?? it.price;
              return ListTile(
                leading: p?.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p!.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.fastfood, size: 32, color: Colors.grey),
                      ),
                title: Text(name),
                subtitle: Text('x${it.quantity} • RM ${price.toStringAsFixed(2)} each'),
                trailing: Text('RM ${(price * it.quantity).toStringAsFixed(2)}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_loading || _cart == null || _cart!.items.isEmpty) return const SizedBox.shrink();
    // Compute total with the same price fallback logic used in the list items
    final Map<String, Product> byId = { for (final p in _products) p.id: p };
    final computed = _cart!.items.fold<double>(0.0, (sum, it) {
      final p = byId[it.productId];
      final price = p?.price ?? it.price;
      return sum + price * it.quantity;
    });
    final total = (_cart!.total > 0) ? _cart!.total : computed;
    return SafeArea(
      child: Container
        (
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total', style: TextStyle(color: Colors.grey)),
                  Text(
                    'RM ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _api.pauseSession(shopId: widget.shopId, shelfId: widget.shelfId);
                } catch (_) {}
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      shopId: widget.shopId,
                      customerId: widget.customerId,
                      shelfId: widget.shelfId,
                      userName: widget.userName,
                      shelfName: widget.shelfName,
                      prefillName: widget.userName,
                      prefillPhone: widget.userPhone,
                      prefillEmail: widget.userEmail,
                      cartTotal: total,
                    ),
                  ),
                );
              },
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
