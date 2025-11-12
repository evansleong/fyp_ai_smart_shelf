import 'package:flutter/material.dart';

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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: (value - 0.85) / (1 - 0.85),
              child: Transform.scale(
                scale: value,
                child: child,
              ),
            );
          },
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
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront, size: 16),
                    const SizedBox(width: 6),
                    Text('Shelf: ' + shelfName),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Hi, ' + userName, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Return to Shopping: pop Success, then Cart
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                        // Schedule second pop to unwind to ShoppingScreen
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        });
                      }
                    },
                    child: const Text('Back to Shopping'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
