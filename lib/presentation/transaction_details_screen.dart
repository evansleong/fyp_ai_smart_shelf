import 'package:flutter/material.dart';

class TransactionDetailsScreen extends StatelessWidget {
  // This map will hold all the data for the transaction we tapped on
  final Map<String, dynamic> transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    // --- Extract all data from the map ---
    final imageUrl = transaction['imageUrl'] as String?;
    final details = transaction['details'] ?? 'No Details';
    final amount = transaction['amount'] ?? '0.00';
    final shopAddress = transaction['shop_address'] ?? 'Unknown Location';
    final shelf = transaction['shelf'] ?? 'Unknown Shelf';
    final date = transaction['date'] ?? 'No Date';
    final time = transaction['time'] ?? 'No Time';
    final paymentMethod = transaction['payment_method'] ?? 'N/A';
    
    // --- Helper widget for building info rows ---
    Widget buildInfoRow(IconData icon, String label, String value) {
      return ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: TextStyle(color: Colors.grey.shade700)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Image and Price Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias, // Ensures image respects border
              child: Column(
                children: [
                  (imageUrl != null)
                      ? Image.network(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.inventory_2_outlined,
                                size: 80, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.inventory_2_outlined,
                              size: 80, color: Colors.grey),
                        ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            details,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          'RM $amount',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. Detailed Info Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  buildInfoRow(
                    Icons.store_outlined,
                    'Location',
                    '$shopAddress\nShelf: $shelf',
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  buildInfoRow(
                    Icons.calendar_month_outlined,
                    'Date & Time',
                    '$date at $time',
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  buildInfoRow(
                    Icons.credit_card_outlined,
                    'Payment Method',
                    paymentMethod,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}