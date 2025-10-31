import 'package:flutter/material.dart';
import 'home_screen.dart'; // We will navigate here on success
// --- NEW IMPORTS ---
import '../core/services/api_service.dart';
import '../core/widgets/camera_screen.dart';
import 'dart:io';
import 'dart:convert';
// --- END NEW IMPORTS ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- REMOVED FormKey and Controllers ---
  bool _isVerifying = false; // Renamed from _isLoading
  final ApiService _apiService = ApiService(); // Add ApiService

  // --- MODIFIED: This is now the face scan logic ---
  Future<void> _scanFaceAndLogin() async {
    // 1. Navigate to CameraScreen
    final String? imagePath = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          scanMode: CameraScanMode.face,
        ),
      ),
    );

    if (imagePath == null || !mounted) return;

    setState(() {
      _isVerifying = true;
    });

    try {
      // 2. Read image and call verification service
      final imageBytes = await File(imagePath).readAsBytes();
      final String imageBase64 = base64Encode(imageBytes);
      final user = await _apiService.verifyFace(imageBase64); // This is the login

      // 3. Handle success
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user['name']}!'),
          backgroundColor: Colors.green,
        ),
      );

      // 4. Navigate to HomeScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      // 5. Handle errors (e.g., face not recognized)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 6. Stop loading
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }
  // --- END MODIFIED ---

  @override
  void dispose() {
    // Removed controllers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Welcome Back",
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Scan your face to log in.", // <-- Updated text
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                
                // --- REMOVED THE Card/Form ---

                // --- ADDED Face Scan UI ---
                const Icon(
                  Icons.face_retouching_natural,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please scan your face to log in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 40),
                _isVerifying
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _scanFaceAndLogin,
                          icon: const Icon(Icons.camera_front),
                          label: const Text('Scan Face to Login'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                // --- END ADDED UI ---
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        // Pop back to the welcome screen, which has the Register button
                        Navigator.of(context).pop();
                      },
                      child: const Text('Register Here'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

