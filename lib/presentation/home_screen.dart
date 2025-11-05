import 'package:flutter/material.dart';
import 'transaction_history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  // 1. Add this field to receive the user data
  final Map<String, dynamic> user;

  // 2. Update the constructor to require the user
  const HomeScreen({
    super.key,
    required this.user,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 3. Change _widgetOptions from 'static const' to 'late final'
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();

    // 4. Get the user ID from the 'widget.user' map
    //    Based on your 'shopper-users' table, the ID is 'shp_user_id'
    // --- AFTER (Safe) ---
    final String shpUserId = widget.user['shp_user_id'] ?? '';

    // 5. Initialize the list with the user data
    _widgetOptions = <Widget>[
      // Pass the ID to TransactionHistoryScreen
      TransactionHistoryScreen(shpUserId: shpUserId),

      // Pass the whole user map to ProfileScreen
      ProfileScreen(user: widget.user),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // 6. This now uses the initialized list
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
