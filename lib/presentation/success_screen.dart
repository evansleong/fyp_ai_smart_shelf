import 'package:flutter/material.dart';
import 'shopping_screen.dart';

class SuccessScreen extends StatelessWidget {
  final String shelfId;
  final String userName;
  final String shelfName;
  final String shopId;
  final String customerId;

  const SuccessScreen({
    super.key,
    required this.shelfId,
    required this.userName,
    required this.shelfName,
    required this.shopId,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Successful')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Thank you! Your payment was successful.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShoppingScreen(
                          shelfId: shelfId,
                          userName: userName,
                          shelfName: shelfName,
                          shopId: shopId,
                          customerId: customerId,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Back to Shopping'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
