import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  /// Requests foreground + background location permissions and battery optimization exemption
  static Future<bool> initializeLocationAndBatteryExemption() async {
    // 1. Request standard foreground location permission
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (kDebugMode) debugPrint('[LOCATION] Foreground permission denied.');
      return false;
    }

    // 2. Request background ("Allow all the time") permission
    var bgStatus = await Permission.locationAlways.request();
    if (kDebugMode) {
      debugPrint('[LOCATION] Background permission status: $bgStatus');
    }

    // 3. Request battery optimization exemption so Android doesn't kill tracking
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return true;
  }

  /// Fetches current coordinates formatted as "lat,lng" for SOS or Geofence checks
  static Future<String?> getCurrentCoordinatesString() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      if (kDebugMode) debugPrint('[LOCATION] Failed to get position: $e');
      return null;
    }
  }
}
