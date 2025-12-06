import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'register_details_screen.dart';
import '../core/services/api_service.dart';
import 'face_liveness_webview.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _FaceLoginCard extends StatelessWidget {
  final bool isVerifying;
  final VoidCallback onScan;

  const _FaceLoginCard({
    required this.isVerifying,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(Icons.verified_user,
                  size: 32, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome Back',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use Face ID to access your smart shelf experience instantly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _InfoChip(
                  icon: Icons.lock,
                  label: 'Secure',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _InfoChip(
                  icon: Icons.flash_on,
                  label: '10s Login',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          isVerifying
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.camera_front),
                  label: const Text('Scan Face to Login'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
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
      // Calls Lambda to get a session ID from Tokyo
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
      // pass 'LOGIN_APP' as a placeholder shelfId. 
      // The backend defaults to action='login', so it won't trigger IoT.
      final user = await _apiService.verifyLiveness(
        sessionId: sessionId,
        shelfId: 'LOGIN_APP', 
        action: 'login',
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
      appBar: AppBar(
        title: const Text('Login'),
        leading: const BackButton(),
      ),
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FaceLoginCard(
                    isVerifying: _isVerifying,
                    onScan: _scanFaceAndLogin,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterDetailsScreen(),
                            ),
                          );
                        },
                        child: const Text('Register Here'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
