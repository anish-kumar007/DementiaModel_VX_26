import 'package:flutter/foundation.dart';

class GeofenceService {
  // Center point of safe zone (e.g., home coordinates)
  static const double safeCenterLat = 28.6139;
  static const double safeCenterLng = 77.2090;
  static const double maxRadiusMeters = 500.0;

  /// Checks if given coordinates are within the safe geofence radius
  static bool checkIfInsideSafeZone(double currentLat, double currentLng) {
    // Simplified distance approximation for hackathon speed (Haversine formula or delta check)
    // For demo purposes, we can return true/false based on a mock state or threshold
    double distanceDiff =
        (currentLat - safeCenterLat).abs() + (currentLng - safeCenterLng).abs();
    // Rough scale: 0.001 deg is ~111 meters
    bool isInside = distanceDiff < 0.005;
    if (kDebugMode) {
      debugPrint(
        '[GEOFENCE] Lat: $currentLat, Lng: $currentLng | Inside Safe Zone: $isInside',
      );
    }
    return isInside;
  }
}
