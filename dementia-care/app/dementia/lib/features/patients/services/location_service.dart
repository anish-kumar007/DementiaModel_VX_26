import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';

class LocationService {
  static final Battery _battery = Battery();

  /// Requests notification, foreground & background location permissions,
  /// and guides the user to disable battery optimization.
  static Future<bool> initializeLocationAndBatteryExemption() async {
    // 1. Android 13+ notification permission (required for foreground service notice)
    await Permission.notification.request();

    // 2. Request standard foreground location permission
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (kDebugMode) debugPrint('[LOCATION] Foreground permission denied.');
      return false;
    }

    // 3. Request background ("Allow all the time") permission
    final bgStatus = await Permission.locationAlways.request();
    if (kDebugMode) {
      debugPrint('[LOCATION] Background permission status: $bgStatus');
    }

    // 4. Request battery optimization exemption so Android doesn't kill tracking
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return true;
  }

  /// Returns Android foreground service settings so a persistent
  /// "Location sharing is on" notification stays visible.
  static AndroidSettings getForegroundTrackingSettings({bool isMoving = true}) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: isMoving ? 15 : 50,
      intervalDuration: isMoving
          ? const Duration(seconds: 45)
          : const Duration(minutes: 7),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Dementia Care Companion',
        notificationText: 'Location sharing is on to keep you safe.',
        enableWakeLock: true,
      ),
    );
  }

  /// One high-accuracy fix, dropping low-accuracy readings (over 100 m).
  static Future<Position?> getFilteredPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (position.accuracy > 100.0) {
        if (kDebugMode) {
          debugPrint('[LOCATION] Dropped low-accuracy fix: ${position.accuracy}m');
        }
        return null;
      }
      return position;
    } catch (e) {
      if (kDebugMode) debugPrint('[LOCATION] Failed to get position: $e');
      return null;
    }
  }

  /// Fetches a reading plus battery level in the shape patients/{pid} stores.
  static Future<Map<String, dynamic>?> getFilteredLocationPayload() async {
    final position = await getFilteredPosition();
    if (position == null) return null;
    final batteryLevel = await _battery.batteryLevel;
    final now = DateTime.now();

    return {
      'lastLocation': {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'time': now.millisecondsSinceEpoch,
      },
      'battery': batteryLevel,
      'lastSeen': now.millisecondsSinceEpoch,
    };
  }

  /// Fetches current coordinates formatted as "lat,lng" for SOS or Geofence checks
  static Future<String?> getCurrentCoordinatesString() async {
    final position = await getFilteredPosition();
    if (position == null) return null;
    return '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
  }
}
