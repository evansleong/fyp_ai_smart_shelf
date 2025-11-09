// lib/screens/search_shelves_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/api_service.dart';
import '../core/services/location_service.dart';
import 'shelf_verification_screen.dart';

class SearchShelvesScreen extends StatefulWidget {
  const SearchShelvesScreen({super.key});

  @override
  State<SearchShelvesScreen> createState() => _SearchShelvesScreenState();
}

class _SearchShelvesScreenState extends State<SearchShelvesScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // State variables
  bool _isLoading = false;
  List<dynamic>? _searchResults;
  String _searchTitle = "Nearby Shelves";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Automatically load nearby shelves when the screen opens
    _runAutoDetect();

    // When the user taps the search bar, make sure results are visible
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          // This just rebuilds to make sure the list is visible
          // The auto-detect has already been run by initState
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Helper to build a consistent error snackbar
  SnackBar _buildErrorSnackbar(String message) {
    // Clean up common error messages
    if (message.contains("Exception:")) {
      message = message.split("Exception:")[1].trim();
    }
    return SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    );
  }

  /// 1. Auto-detects user's location and finds nearby shelves
  Future<void> _runAutoDetect() async {
    if (_isLoading) return;

    _searchController.clear(); // Clear any search text
    _searchFocusNode.unfocus(); // Hide keyboard

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = null; // Clear old results
    });

    try {
      final Position position = await _locationService.getCurrentLocation();
      final List<dynamic> nearbyShelves = await _apiService.findNearbyShelves(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _searchResults = nearbyShelves;
        _searchTitle = "Nearby Shelves";
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(_buildErrorSnackbar(e.toString()));
      }
    }
  }

  /// 2. Searches for shelves based on a text query
  Future<void> _runTextSearch(String query) async {
    if (query.isEmpty) return;
    if (_isLoading) return;

    _searchFocusNode.unfocus(); // Hide keyboard
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = null; // Clear old results
    });
    final messenger = ScaffoldMessenger.of(context); // For errors

    try {
      // --- 1. GET USER'S CURRENT LOCATION FIRST ---
      final Position position = await _locationService.getCurrentLocation();

      // --- 2. CALL API with query AND location ---
      final List<dynamic> nearbyShelves =
          await _apiService.searchNearbyShelvesByText(
        query,
        position.latitude, // Pass user's lat
        position.longitude, // Pass user's lon
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _searchResults = nearbyShelves;
        // Get the name of the geocoded area (e.g., "Kuala Lumpur")
        _searchTitle = nearbyShelves.isNotEmpty
            ? "Results near \"${nearbyShelves[0]['search_origin']}\""
            : "Results for \"$query\"";
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        messenger.showSnackBar(_buildErrorSnackbar(e.toString()));
      }
    }
  }

  /// 3. Navigates to the selected shelf
  Future<void> _navigateToShelf(String shelfId) async {
    if (shelfId.isEmpty) return;

    try {
      // We must verify the shelf exists before navigating
      await _apiService.awsShelfLookup(shelfId);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShelfVerificationScreen(shelfId: shelfId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(_buildErrorSnackbar(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The Search Bar
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: false, // Don't open keyboard immediately
          decoration: InputDecoration(
            hintText: 'Search for shops or areas...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: Colors.grey.shade200,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: _runTextSearch,
        ),
        actions: [
          // The "auto-detect" button
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'My Location',
            onPressed: _isLoading ? null : _runAutoDetect,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Builds the main body content based on the current state
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "Error: $_errorMessage",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    if (_searchResults == null) {
      // Initial state before anything has loaded (should be rare)
      return const Center(
          child: Text('Search for a shelf or use auto-detect.'));
    }

    if (_searchResults!.isEmpty) {
      return Center(
        child: Text(
          'No shelves found for "$_searchTitle"',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // --- We have results, show them in a list ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            _searchTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults!.length,
            itemBuilder: (context, index) {
              final shelf = _searchResults![index];
              final shelfId = shelf['shelf_id']?.toString() ?? '';
              final shelfName =
                  shelf['shelf_name']?.toString() ?? 'Unnamed Shelf';
              final shopName = shelf['shop_name']?.toString() ?? 'Unknown Shop';
              final distance = shelf['distance_km']?.toString() ?? '??';
              final location = shelf['shelf_location'] ?? '...';

              return ListTile(
                leading: const Icon(Icons.shelves, color: Colors.blueGrey),
                title: Text(shelfName),
                subtitle: Text("$shopName • $location"),
                trailing: Text(
                  "$distance km",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: null,
              );
            },
          ),
        ),
      ],
    );
  }
}
