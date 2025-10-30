class Product {
  final String id;
  final String name;
  final double price;
  final int stock; // This is the 'quantity' from the shelf
  final String? imageUrl;
  final String? halalStatus;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.imageUrl,
    this.halalStatus,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['productId'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      stock: (json['quantity'] as num).toInt(),
      imageUrl: json['imageUrl'],
      halalStatus: json['halalStatus'],
    );
  }
}