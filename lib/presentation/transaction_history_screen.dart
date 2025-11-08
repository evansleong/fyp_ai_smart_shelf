import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import 'transaction_details_screen.dart'; 

class TransactionHistoryScreen extends StatefulWidget {
  final String shpUserId;

  const TransactionHistoryScreen({
    super.key,
    required this.shpUserId,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    
    // --- TEMPORARY TEST --- KAH YUNG DATA
    _transactionsFuture = _apiService.getCustomerOrders("9a3e4a12-0652-441d-959b-584bd07ed05a");
    
    // --- REAL CODE ---
    // _transactionsFuture = _apiService.getCustomerOrders(widget.shpUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load history:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no transaction history yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // --- NEW: Grouping Logic ---
          final transactions = snapshot.data!;
          final List<dynamic> groupedItems = [];
          String? currentDateHeader;

          for (final transaction in transactions) {
            final date = transaction['date'] ?? 'Unknown Date';
            if (date != currentDateHeader) {
              currentDateHeader = date;
              groupedItems.add(date); // Add the date header
            }
            groupedItems.add(transaction); // Add the transaction item
          }
          // --- END: Grouping Logic ---

          return ListView.builder(
            // Use the new grouped list
            itemCount: groupedItems.length,
            itemBuilder: (context, index) {
              
              // Get the item. It's either a String (header) or a Map (transaction)
              final item = groupedItems[index];

              // --- NEW: Build a Date Header ---
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    item, // This is the date string, e.g., "2025-11-05"
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                  ),
                );
              }

              // --- NEW: Build a Transaction ListTile ---
              if (item is Map<String, dynamic>) {
                final transaction = item;
                
                final imageUrl = transaction['imageUrl'] as String?;
                
                // Get data for the simplified subtitle
                final paymentMethod = transaction['payment_method'] ?? 'N/A';
                final time = transaction['time'] ?? 'No Time'; // <-- Get time

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: (imageUrl != null)
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                  );
                                },
                              )
                            : Container( // Placeholder if no image URL
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                              ),
                      ),
                    ),
                    
                    title: Text(
                      transaction['details'] ?? 'No Details',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    
                    // --- MODIFIED: Subtitle is now 'Shelf • Time' ---
                    subtitle: Text(
                      '$paymentMethod • $time', // Line 1: Shelf & Time
                      style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                    
                    // --- MODIFIED: Set to false for a cleaner look ---
                    isThreeLine: false,
                    
                    trailing: Text(
                      '- RM ${transaction['amount'] ?? '0.00'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailsScreen(
                            // Pass the entire transaction map to the next screen
                            transaction: transaction,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }

              // Fallback for safety
              return Container();
            },
          );
        },
      ),
    );
  }
}