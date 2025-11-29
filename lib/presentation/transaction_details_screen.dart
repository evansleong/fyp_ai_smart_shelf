import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final shopName = transaction['shop_name'] ?? transaction['details'] ?? 'Purchase';
    final amount = _parseAmount(transaction['amount']);
    final shopAddress = transaction['shop_address'] ?? 'Unknown Location';
    final shelfLocation = transaction['shelf'] ?? transaction['shelf_location'] ?? 'Unknown Shelf';
    final date = transaction['date'] ?? '';
    final time = transaction['time'] ?? '';
    final paymentMethod = transaction['payment_method'] ?? 'Card';
    final items = _parseItems(transaction);
    final totalAmount = _calculateTotal(items, amount);

    String formattedDate = '';
    String formattedTime = '';
    if (date.isNotEmpty && time.isNotEmpty) {
      try {
        final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
        final dateTimeFormat = DateFormat('dd MMM yyyy');
        final timeFormat = DateFormat('hh:mm a');
        final DateTime parsedDateTime = inputFormat.parse('$date $time');
        formattedDate = dateTimeFormat.format(parsedDateTime);
        formattedTime = timeFormat.format(parsedDateTime);
      } catch (e) {
        formattedDate = date;
        formattedTime = time;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Transaction Details',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderCard(shopName, totalAmount, formattedDate, formattedTime),
            const SizedBox(height: 16),
            if (items.isNotEmpty) _buildItemsSection(items),
            if (items.isEmpty) _buildSingleItemCard(transaction),
            const SizedBox(height: 16),
            _buildInfoCard(shopAddress, shelfLocation, formattedDate, formattedTime, paymentMethod),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String shopName, double totalAmount, String date, String time) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF6366F1),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date.isNotEmpty || time.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          date.isNotEmpty && time.isNotEmpty
                              ? '$date • $time'
                              : date.isNotEmpty
                                  ? date
                                  : time,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'RM ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
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

  Widget _buildItemsSection(List<TransactionItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Items (${items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;
            return _buildItemRow(item, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildItemRow(TransactionItem item, bool isLast) {
    final subtotal = item.price * item.quantity;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey.shade400,
                            size: 24,
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.name} x ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'RM ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 80),
      ],
    );
  }

  Widget _buildSingleItemCard(Map<String, dynamic> transaction) {
    final details = transaction['details'] ?? transaction['shop_name'] ?? 'Purchase';
    final amount = _parseAmount(transaction['amount']);
    final imageUrl = transaction['imageUrl'] as String?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                details,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Text(
              'RM ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String shopAddress, String shelfLocation, String date, String time, String paymentMethod) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.location_on_outlined, 'Shelf Location', shelfLocation),
          const Divider(height: 1, indent: 80),
          _buildInfoRow(Icons.store_outlined, 'Shop Location', shopAddress),
          const Divider(height: 1, indent: 80),
          if (date.isNotEmpty || time.isNotEmpty)
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Date & Time',
              date.isNotEmpty && time.isNotEmpty ? '$date at $time' : date.isNotEmpty ? date : time,
            ),
          if (date.isNotEmpty || time.isNotEmpty) const Divider(height: 1, indent: 80),
          _buildInfoRow(Icons.payment_outlined, 'Payment Method', paymentMethod),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount.toString()) ?? 0.0;
  }

  List<TransactionItem> _parseItems(Map<String, dynamic> transaction) {
    final items = <TransactionItem>[];
    
    if (transaction['items'] != null && transaction['items'] is List) {
      final itemsList = transaction['items'] as List;
      for (var item in itemsList) {
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString() ?? 'Unknown Item';
          final price = _parseAmount(item['price'] ?? item['unit_price']);
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final imageUrl = item['imageUrl']?.toString() ?? item['image_url']?.toString();
          items.add(TransactionItem(
            name: name,
            price: price,
            quantity: quantity,
            imageUrl: imageUrl,
          ));
        }
      }
    }
    
    return items;
  }

  double _calculateTotal(List<TransactionItem> items, double fallbackAmount) {
    if (items.isEmpty) return fallbackAmount;
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }
}

class TransactionItem {
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  TransactionItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });
}