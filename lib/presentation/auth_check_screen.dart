import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import 'transaction_history_screen.dart'; // Your main "home" screen

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Check login status as soon as this screen loads
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Get the storage instance
    final prefs = await SharedPreferences.getInstance();
    
    // Try to get the saved user ID
    final String? shpUserId = prefs.getString('shp_user_id');

    if (!mounted) return;

    if (shpUserId != null && shpUserId.isNotEmpty) {
      // --- USER IS LOGGED IN ---
      // Navigate to the main app screen and remove all other screens
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TransactionHistoryScreen(shpUserId: shpUserId),
        ),
      );
    } else {
      // --- USER IS NOT LOGGED IN ---
      // Navigate to the Welcome/Login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while we check storage
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}