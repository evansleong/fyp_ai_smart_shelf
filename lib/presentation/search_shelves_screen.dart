import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/api_service.dart';
import '../core/services/location_service.dart';
import 'shelf_details_screen.dart';
import 'dart:async';

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

  Timer? _debounce;

  // State variables
  bool _isLoading = false;
  List<dynamic>? _searchResults;
  List<dynamic>? _cachedNearbyShelves; // Cache for nearby shelves
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
        setState(() {});
      }
    });

    // Listen to text changes to update clear button visibility
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
        _cachedNearbyShelves = nearbyShelves; // Save to cache
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        // User is searching - run text search
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        _runTextSearch(query);
      } else {
        // Search bar is empty - use cached nearby shelves if available
        if (_cachedNearbyShelves != null && _cachedNearbyShelves!.isNotEmpty) {
          setState(() {
            _isLoading = false;
            _searchResults = _cachedNearbyShelves;
            _searchTitle = "Nearby Shelves";
            _errorMessage = null;
          });
        } else {
          // No cache available - detect location
          _runAutoDetect();
        }
      }
    });
  }

  /// 2. Searches for shelves based on a text query
  Future<void> _runTextSearch(String query) async {
    if (query.isEmpty) return;

    try {
      final Position position = await _locationService.getCurrentLocation();

      final List<dynamic> nearbyShelves =
          await _apiService.searchNearbyShelvesByText(
        query,
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        // --- CHANGE 2: Turn OFF loading on success ---
        _isLoading = false;
        _searchResults = nearbyShelves;
        _searchTitle = nearbyShelves.isNotEmpty
            ? "Results for \"$query\""
            : "No matches for \"$query\"";
        _errorMessage = null;
      });
    } catch (e) {
      print("Autofill error: $e");

      if (mounted) {
        setState(() {
          // --- CHANGE 3: Turn OFF loading on error ---
          _isLoading = false;
        });
      }
    }
  }

  /// 3. Navigates to the selected shelf
  void _navigateToShelf(String shelfId, Map<String, dynamic> shelfData) {
    if (shelfId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShelfDetailsScreen(
          shelfId: shelfId,
          shelfData: shelfData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFF1F5F9),
          ],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: _buildSearchBar(),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: 'Search for shops or areas...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 15,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search,
              color: Colors.grey.shade600,
              size: 22,
            ),
          ),
          suffixIcon: _buildSuffixIcon(),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSuffixIcon() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6366F1),
          ),
        ),
      );
    }

    // Show clear button if there's text, otherwise show location button
    if (_searchController.text.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.clear,
              color: Colors.grey.shade600,
              size: 20,
            ),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
            tooltip: 'Clear search',
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.my_location,
                color: Color(0xFF6366F1),
                size: 22,
              ),
              onPressed: _runAutoDetect,
              tooltip: 'Find nearby shelves',
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(
          Icons.my_location,
          color: Color(0xFF6366F1),
          size: 22,
        ),
        onPressed: _runAutoDetect,
        tooltip: 'Find nearby shelves',
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6366F1),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding nearby shelves...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to find shelves',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!.replaceFirst("Exception: ", ""),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _runAutoDetect,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 48,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for shelves',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search by shop name or area',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No shelves found',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchTitle.contains('Results')
                  ? 'Try a different search term'
                  : 'No nearby shelves available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF6366F1).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shelves,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _searchTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_searchResults!.length} ${_searchResults!.length == 1 ? 'shelf' : 'shelves'} found',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _searchResults!.length,
            itemBuilder: (context, index) {
              final shelf = _searchResults![index];
              return _buildShelfCard(
                  shelf, index == _searchResults!.length - 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShelfCard(Map<String, dynamic> shelf, bool isLast) {
    final shelfId = shelf['shelf_id']?.toString() ?? '';
    final shelfName = shelf['shelf_name']?.toString() ?? 'Unnamed Shelf';
    final shopName = shelf['shop_name']?.toString() ?? 'Unknown Shop';
    final distance = shelf['distance_km']?.toString() ?? '??';
    final location =
        shelf['shelf_location']?.toString() ?? 'Location not available';
    final halalStatus = shelf['halal_status']?.toString() ?? '';
    final isHalal = halalStatus == 'Halal';

    double distanceValue = 0.0;
    try {
      distanceValue = double.parse(distance);
    } catch (e) {
      distanceValue = 0.0;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToShelf(shelfId, shelf),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.2),
                        const Color(0xFF6366F1).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shelves,
                    color: Color(0xFF6366F1),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelfName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shopName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (halalStatus.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isHalal
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isHalal
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFEF4444).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHalal ? Icons.verified : Icons.info_outline,
                                size: 12,
                                color: isHalal
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                halalStatus,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isHalal
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: distanceValue < 1.0
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : distanceValue < 5.0
                                ? const Color(0xFFF59E0B).withOpacity(0.1)
                                : const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.near_me,
                            size: 14,
                            color: distanceValue < 1.0
                                ? const Color(0xFF10B981)
                                : distanceValue < 5.0
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceValue < 1.0
                                ? '${(distanceValue * 1000).toStringAsFixed(0)}m'
                                : '$distance km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: distanceValue < 1.0
                                  ? const Color(0xFF10B981)
                                  : distanceValue < 5.0
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
