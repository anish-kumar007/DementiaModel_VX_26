import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeofenceService {
  // Default center point of safe zone (overridden by patients/{pid}.safeZone)
  static const double defaultSafeCenterLat = 28.6139;
  static const double defaultSafeCenterLng = 77.2090;
  static const double defaultRadiusMeters = 500.0;

  static int _consecutiveOutsideReadings = 0;

  /// Checks distance in meters using Geolocator's geodesic distance calculation.
  static bool checkIfInsideSafeZone({
    required double currentLat,
    required double currentLng,
    double centerLat = defaultSafeCenterLat,
    double centerLng = defaultSafeCenterLng,
    double radiusMeters = defaultRadiusMeters,
  }) {
    final double distanceMeters = Geolocator.distanceBetween(
      centerLat,
      centerLng,
      currentLat,
      currentLng,
    );

    final bool isInside = distanceMeters <= radiusMeters;

    if (kDebugMode) {
      debugPrint(
        '[GEOFENCE] Distance: ${distanceMeters.toStringAsFixed(1)}m / ${radiusMeters}m | Inside: $isInside',
      );
    }
    return isInside;
  }

  /// Tracks consecutive outside readings. Returns true when 2 consecutive
  /// readings occur outside the safeZone so the UI triggers "Are you okay?".
  static bool recordReadingAndShouldPrompt({
    required double currentLat,
    required double currentLng,
    double centerLat = defaultSafeCenterLat,
    double centerLng = defaultSafeCenterLng,
    double radiusMeters = defaultRadiusMeters,
  }) {
    final isInside = checkIfInsideSafeZone(
      currentLat: currentLat,
      currentLng: currentLng,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusMeters: radiusMeters,
    );

    if (isInside) {
      _consecutiveOutsideReadings = 0;
      return false;
    }

    _consecutiveOutsideReadings++;
    return _consecutiveOutsideReadings >= 2;
  }

  static void resetOutsideCounter() {
    _consecutiveOutsideReadings = 0;
  }
}
