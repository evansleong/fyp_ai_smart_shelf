import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    _transactionsFuture =
        _apiService.getCustomerOrders("9a3e4a12-0652-441d-959b-584bd07ed05a");
    
    // Use the actual user ID passed from HomeScreen
    //_transactionsFuture = _apiService.getCustomerOrders(widget.shpUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      // --- This is the FutureBuilder logic moved from HomeScreen ---
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

          // --- Sorting Logic ---
          final transactions = snapshot.data!;
          transactions.sort((a, b) {
            try {
              final String aDateStr = a['date'] ?? '';
              final String aTimeStr = a['time'] ?? '';
              final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
              final DateTime aDateTime =
                  inputFormat.parse('$aDateStr $aTimeStr');

              final String bDateStr = b['date'] ?? '';
              final String bTimeStr = b['time'] ?? '';
              final DateTime bDateTime =
                  inputFormat.parse('$bDateStr $bTimeStr');

              return bDateTime.compareTo(aDateTime);
            } catch (e) {
              return 0;
            }
          });

          // --- Grouping Logic ---
          final List<dynamic> groupedItems = [];
          String? currentMonthHeader;
          final DateFormat headerFormat = DateFormat('MMMM yyyy');

          for (final transaction in transactions) {
            final String dateString = transaction['date'] ?? '';
            String monthHeader = "UNKNOWN MONTH";
            try {
              final DateTime date = DateTime.parse(dateString);
              monthHeader = headerFormat.format(date).toUpperCase();
            } catch (e) {
              if (dateString.isNotEmpty) {
                monthHeader = dateString;
              }
            }

            if (monthHeader != currentMonthHeader) {
              currentMonthHeader = monthHeader;
              groupedItems.add(monthHeader);
            }
            groupedItems.add(transaction);
          }

          // --- List Building Logic ---
          return ListView.builder(
            itemCount: groupedItems.length,
            // Add padding for the last item
            padding: const EdgeInsets.only(bottom: 24.0), 
            itemBuilder: (context, index) {
              final item = groupedItems[index];

              // Monthly Header
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    item.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                  ),
                );
              }

              // Transaction ListTile
              if (item is Map<String, dynamic>) {
                final transaction = item;

                // Amount
                double amount = 0.0;
                if (transaction['amount'] != null) {
                  amount =
                      double.tryParse(transaction['amount'].toString()) ?? 0.0;
                }
                final String displayAmount =
                    '- RM ${amount.abs().toStringAsFixed(2)}';
                const Color amountColor = Colors.red;

                // Details
                final imageUrl = transaction['imageUrl'] as String?;
                final paymentMethod = transaction['payment_method'] ?? 'N/A';

                // Date/Time Formatting
                final String dateStr = transaction['date'] ?? '';
                final String timeStr = transaction['time'] ?? '';
                String displayTime;

                if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
                  try {
                    final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
                    final outputFormat = DateFormat('dd/MM/yyyy hh:mm a');
                    final DateTime parsedDateTime =
                        inputFormat.parse('$dateStr $timeStr');
                    displayTime = outputFormat.format(parsedDateTime);
                  } catch (e) {
                    displayTime =
                        '${transaction['date']} ${transaction['time']}';
                  }
                } else {
                  displayTime = transaction['time'] ?? 'No Time';
                }

                final String subtitleText = '$displayTime • $paymentMethod';

                // The Card
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    //leading: SizedBox(
                    //  width: 56,
                    //  height: 56,
                    //  child: ClipRRect(
                    //    borderRadius: BorderRadius.circular(8.0),
                    //    child: (imageUrl != null)
                    //        ? Image.network(
                    //            imageUrl,
                    //            fit: BoxFit.cover,
                    //            errorBuilder: (context, error, stackTrace) {
                    //              return Container(
                    //                color: Colors.grey.shade200,
                    //                child: const Icon(
                    //                    Icons.inventory_2_outlined,
                    //                    color: Colors.grey),
                    //              );
                    //            },
                    //          )
                    //        : Container(
                    //            color: Colors.grey.shade200,
                    //            child: const Icon(Icons.inventory_2_outlined,
                    //                color: Colors.grey),
                    //          ),
                    //  ),
                    //),
                    title: Text(
                      transaction['shop_name'] ?? transaction['details'] ?? 'No Details',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      subtitleText,
                      style:
                          TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                    isThreeLine: false,
                    trailing: Text(
                      displayAmount,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailsScreen(
                            transaction: transaction,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
              return Container();
            },
          );
        },
      ),
    );
  }
}