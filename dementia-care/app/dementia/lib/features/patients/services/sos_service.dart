import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import '../../../services/patient_writes.dart';
import 'location_service.dart';

class SosService {
  /// Triggers the SOS flow:
  /// 1. Haptic confirmation
  /// 2. Writes an alert doc to patients/{pid}/alerts (queued if offline)
  /// 3. Refreshes the shared location so the caregiver map is current
  /// 4. Never calls the AI
  /// 5. Opens a pre-filled SMS when the phone looks offline
  ///
  /// Returns true when the alert was written (Firestore queues it offline).
  static Future<bool> triggerEmergencySos({
    String? caregiverPhone,
    bool? isOnline,
  }) async {
    await HapticFeedback.heavyImpact();

    final position = await LocationService.getFilteredPosition();
    final phone = caregiverPhone ?? await _caregiverPhoneFromProfile();

    if (position != null) {
      await PatientWrites.recordLocation(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        battery: await PatientWrites.batteryLevel(),
        source: 'sos',
      );
    }

    final queued = await PatientWrites.logAlert(
      type: 'sos',
      severity: 'critical',
      message: 'The patient pressed the emergency SOS button.',
      lat: position?.latitude,
      lng: position?.longitude,
      accuracy: position?.accuracy,
    );

    final online = isOnline ?? await _hasServerConnection();
    if (!online) {
      await openSmsFallback(
        phoneNumber: phone,
        coordinates: position == null
            ? null
            : '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}',
      );
    }

    return queued;
  }

  /// Manual SMS backup, also offered from the patient home snack bar.
  static Future<bool> openSmsFallback({
    String? phoneNumber,
    String? coordinates,
  }) async {
    final phone = phoneNumber ??
        AppConstants.defaultCaregiverPhone;
    final locationText = coordinates != null
        ? ' Location: https://maps.google.com/?q=$coordinates'
        : '';
    final message = Uri.encodeComponent(
      'EMERGENCY SOS: Your Care Companion user needs immediate help!$locationText',
    );

    final smsUri = Uri.parse('sms:$phone?body=$message');

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

  static Future<String?> _caregiverPhoneFromProfile() async {
    final pid = FirebaseAuth.instance.currentUser?.uid;
    if (pid == null) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('patients')
          .doc(pid)
          .get(const GetOptions(source: Source.server));
      final phone = (snap.data()?['caregiverPhone'] as String?)?.trim();
      return (phone == null || phone.isEmpty)
          ? AppConstants.defaultCaregiverPhone
          : phone;
    } catch (_) {
      return AppConstants.defaultCaregiverPhone;
    }
  }

  /// A short server read is the cheapest way to know if we are really online.
  static Future<bool> _hasServerConnection() async {
    final pid = FirebaseAuth.instance.currentUser?.uid;
    if (pid == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(pid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }
}
