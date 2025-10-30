import 'package:flutter/material.dart';
import 'register_screen.dart'; // 👈 UPDATED PATH
import '../core/widgets/camera_screen.dart';
import 'shelf_verification_screen.dart'; // 👈 UPDATED PATH
import 'login_screen.dart'; // 👈 IMPORT

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2,
                size: 96,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'AI Smart Shelf',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(), // 👈 Use LoginScreen
                      ),
                    );
                  },
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(), // 👈 Use RegisterScreen
                      ),
                    );
                  },
                  child: const Text('Register'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Shelf QR'),
                  onPressed: () async {
                    final qrCodeResult =
                        await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const CameraScreen(
                          scanMode: CameraScanMode.qrCode,
                        ),
                      ),
                    );

                    if (qrCodeResult != null && context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShelfVerificationScreen(
                            shelfId: qrCodeResult,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
