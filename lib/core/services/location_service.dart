import 'package:geolocator/geolocator.dart';
import 'dart:async'; 

/// A service to handle getting the user's GPS location.
class LocationService {
  /// Gets the current user's position.
  /// Throws an exception if permissions are denied or if it times out.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled. Please enable GPS.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        // Use medium accuracy for a much faster result
        desiredAccuracy: LocationAccuracy.medium,
        // Add a 10-second time limit
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException {
      // If it times out, try getting the last known position as a fallback
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        return lastPosition;
      }
      // If both fail, throw an error
      return Future.error(
          'Failed to get location: Request timed out and no last known position was found.');
    } catch (e) {
      // Catch other potential errors (e.g., service turned off mid-request)
      return Future.error('Failed to get location: $e');
    }
  }
}