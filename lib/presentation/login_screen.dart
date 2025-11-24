import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'home_screen.dart';
//import 'home_screen.dart'; 
import '../core/services/api_service.dart';
import '../core/widgets/camera_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'face_liveness_webview.dart';

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
    setState(() {
      _isVerifying = true;
    });

    try {
      // 1. Create Liveness Session
      // Calls your Lambda to get a session ID from Tokyo
      final String sessionId = await _apiService.createLivenessSession();

      if (!mounted) return;

      // 2. Open the WebView Bridge
      final bool? isLivenessSuccessful = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceLivenessWebView(sessionId: sessionId),
        ),
      );

      if (isLivenessSuccessful != true) {
        throw Exception("Liveness check failed or was cancelled.");
      }

      // 3. Verify Result (Login)
      // We pass 'LOGIN_APP' as a placeholder shelfId. 
      // The backend defaults to action='login', so it won't trigger IoT.
      final user = await _apiService.verifyLiveness(
        sessionId: sessionId,
        shelfId: 'LOGIN_APP', 
      );

      // --- DEBUG PRINT ---
      print('--- USER DATA FROM LOGIN ---');
      print(user);

      // 4. Process User Data & Login
      final String shpUserId = (user['shp_user_id'] ?? user['userId'] ?? user['id'])?.toString() ?? '';
      
      if (shpUserId.isEmpty) {
        throw Exception("User ID not found in database.");
      }
      
      // Save to SharedPreferences (Session Persistence)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shp_user_id', shpUserId); 

      // 5. Handle Success & Navigate
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user['name']}!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(shpUserId: shpUserId)),
      );

    } catch (e) {
      // 6. Handle Errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Failed: ${e.toString().replaceAll("Exception:", "")}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      // 7. Stop Loading
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

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
