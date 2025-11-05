class CartItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;

  CartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Handle both plain JSON and possible DynamoDB attribute map shapes.
    // If this entry is of the form {'M': { 'product_id': {'S': '...'}, 'quantity': {'N': '1'}, ... }},
    // unwrap the inner map first.
    final Map<String, dynamic> src =
        (json.containsKey('M') && json['M'] is Map<String, dynamic>)
            ? (json['M'] as Map<String, dynamic>)
            : json;

    String asString(dynamic v) => v == null
        ? ''
        : (v is Map && v.containsKey('S'))
            ? (v['S']?.toString() ?? '')
            : v.toString();
    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is Map && v.containsKey('N')) {
        return double.tryParse(v['N']?.toString() ?? '') ?? 0.0;
      }
      return double.tryParse(v.toString()) ?? 0.0;
    }
    int asInt(dynamic v) => asDouble(v).toInt();

    return CartItem(
      productId: asString(src['product_id']),
      name: asString(src['name']).isEmpty ? '(Unknown)' : asString(src['name']),
      quantity: asInt(src['quantity']),
      price: asDouble(src['price']),
    );
  }
}

class Cart {
  final String customerId;
  final String shopId;
  final List<CartItem> items;
  final double total;
  final DateTime? lastUpdated;

  Cart({
    required this.customerId,
    required this.shopId,
    required this.items,
    required this.total,
    this.lastUpdated,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>? ?? []);

    String asString(dynamic v) => v?.toString() ?? '';
    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final parsedItems = itemsJson
        .whereType<dynamic>()
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Prefer server total if present; otherwise compute from items.
    final double computedTotal = parsedItems
        .fold(0.0, (sum, it) => sum + (it.price * it.quantity));
    final double total = json.containsKey('total')
        ? asDouble(json['total'])
        : computedTotal;

    // Support both 'last_updated' and 'updated_at'
    final String? updatedStr = (json['last_updated'] ?? json['updated_at'])?.toString();

    return Cart(
      customerId: asString(json['customer_id']),
      shopId: asString(json['shop_id']),
      items: parsedItems,
      total: total,
      lastUpdated: updatedStr != null ? DateTime.tryParse(updatedStr) : null,
    );
  }
}
