import 'package:flutter/material.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  // Mock data for the UI
  final List<Map<String, String>> _transactions = const [
    {
      'date': '2025-10-30',
      'details': 'Chapi (1), 100 Plus (1)',
      'amount': '7.50',
      'shelf': 'Shelf 1 (Store Entrance)'
    },
    {
      'date': '2025-10-28',
      'details': 'Coca-Cola (2)',
      'amount': '5.00',
      'shelf': 'Shelf 3 (Aisle 4)'
    },
    {
      'date': '2025-10-27',
      'details': 'Lays Chips (1)',
      'amount': '4.20',
      'shelf': 'Shelf 1 (Store Entrance)'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: ListView.builder(
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: const Icon(Icons.shopping_cart_outlined,
                  color: Colors.blueAccent),
              title: Text(
                transaction['details']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                  '${transaction['shelf']!}\n${transaction['date']!}',
                  style: TextStyle(color: Colors.grey.shade600)),
              trailing: Text(
                '- RM ${transaction['amount']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
