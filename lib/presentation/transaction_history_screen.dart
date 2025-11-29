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
    _transactionsFuture =
        _apiService.getCustomerOrdersHistory(widget.shpUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Transaction History',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load history',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transaction history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

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

          final List<dynamic> groupedItems = [];
          String? currentMonthHeader;
          final DateFormat headerFormat = DateFormat('MMMM yyyy');

          for (final transaction in transactions) {
            final String dateString = transaction['date'] ?? '';
            String monthHeader = "UNKNOWN MONTH";
            try {
              final DateTime date = DateTime.parse(dateString);
              monthHeader = headerFormat.format(date);
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

          return ListView.builder(
            itemCount: groupedItems.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final item = groupedItems[index];

              if (item is String) {
                return _buildMonthHeader(item);
              }

              if (item is Map<String, dynamic>) {
                return _buildTransactionCard(item, context);
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader(String month) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        month,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction, BuildContext context) {
    double amount = 0.0;
    if (transaction['amount'] != null) {
      amount = double.tryParse(transaction['amount'].toString()) ?? 0.0;
    }
    final String displayAmount = 'RM ${amount.abs().toStringAsFixed(2)}';
    
    final paymentMethod = transaction['payment_method'] ?? 'Card';
    final shopName = transaction['shop_name'] ?? transaction['details'] ?? 'Purchase';
    
    final String dateStr = transaction['date'] ?? '';
    final String timeStr = transaction['time'] ?? '';
    String displayDate = '';
    String displayTime = '';

    if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      try {
        final inputFormat = DateFormat('yyyy-MM-dd hh:mm a');
        final dateTimeFormat = DateFormat('dd MMM yyyy');
        final timeFormat = DateFormat('hh:mm a');
        final DateTime parsedDateTime = inputFormat.parse('$dateStr $timeStr');
        displayDate = dateTimeFormat.format(parsedDateTime);
        displayTime = timeFormat.format(parsedDateTime);
      } catch (e) {
        displayDate = dateStr;
        displayTime = timeStr;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Color(0xFF6366F1),
                    size: 24,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (displayDate.isNotEmpty) ...[
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                          Text(
                            displayTime.isNotEmpty ? displayTime : paymentMethod,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        paymentMethod,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}