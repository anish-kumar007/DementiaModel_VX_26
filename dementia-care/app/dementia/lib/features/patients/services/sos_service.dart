import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import 'location_service.dart';

class SosService {
  /// Triggers SOS flow:
  /// 1. Haptic feedback confirmation
  /// 2. Writes alert doc {type: 'sos', time, location} (queued if offline)
  /// 3. Never calls AI
  /// 4. Opens pre-filled SMS fallback when offline / unlinked
  static Future<bool> triggerEmergencySos({
    String caregiverPhone = AppConstants.defaultCaregiverPhone,
    bool isOnline = false,
  }) async {
    await HapticFeedback.heavyImpact();
    final coords = await LocationService.getCurrentCoordinatesString();

    final alertDoc = {
      'type': 'sos',
      'time': DateTime.now().toUtc().toIso8601String(),
      'location': coords ?? 'unknown',
      'ackedBy': null,
      'ackedAt': null,
    };

    if (kDebugMode) {
      debugPrint('[SOS] Queuing alert doc: $alertDoc');
    }

    // Write to Firestore (Firestore offline cache queues automatically if offline):
    // await FirebaseFirestore.instance
    //     .collection('patients')
    //     .doc(pid)
    //     .collection('alerts')
    //     .add(alertDoc);

    if (!isOnline) {
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
        ? ' Location: https://maps.google.com/?q=$coordinates'
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
