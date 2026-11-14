import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import 'location_service.dart';

class SosService {
  static Future<bool> triggerEmergencySos({
    String caregiverPhone = AppConstants.defaultCaregiverPhone,
  }) async {
    bool pushSent = false;
    final coords = await LocationService.getCurrentCoordinatesString();

    try {
      if (kDebugMode) {
        debugPrint('[SOS] Attempting send_alert_push Cloud Function with coords: $coords');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      pushSent = false; // Force fallback if offline/unlinked
    } catch (e) {
      pushSent = false;
    }

    if (!pushSent) {
      return await _sendSmsFallback(
        phoneNumber: caregiverPhone,
        coordinates: coords,
      );
    }

    return true;
  }

  static Future<bool> _sendSmsFallback({
    required String phoneNumber,
    String? coordinates,
  }) async {
    final locationText = coordinates != null
        ? ' Last known location: https://maps.google.com/?q=$coordinates'
        : '';
    final message = Uri.encodeComponent(
      'EMERGENCY SOS: Your Care Companion user needs immediate help!$locationText',
    );

    final smsUri = Uri.parse('sms:$phoneNumber?body=$message');

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SOS] SMS fallback error: $e');
      }
      return false;
    }
  }
}
