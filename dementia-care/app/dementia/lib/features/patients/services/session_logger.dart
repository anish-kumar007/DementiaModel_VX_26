import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SessionLogger {
  /// Logs game session metrics matching Firestore schema:
  /// patients/{pid}/sessions/{id} ->
  /// {game, level, accuracy, avgResponseMs, language, timestamp}
  static Future<void> logSession({
    required String game,
    required int level,
    required double accuracy,
    required int avgResponseMs,
    required String language,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('[SESSION LOG] Skipped: No authenticated user');
      return;
    }
    
    final patientId = user.uid; // The patient's Auth UID is their pid

    final sessionData = <String, dynamic>{
      'game': game,
      'level': level,
      'accuracy': double.parse(accuracy.toStringAsFixed(2)),
      'avgResponseMs': avgResponseMs,
      'language': language,
      // CRITICAL FIX: Must be a Firestore Timestamp, not a String.
      // The caregiver dashboard filters with `where('timestamp', isGreaterThanOrEqualTo: Timestamp...)`
      'timestamp': Timestamp.fromDate(DateTime.now().toUtc()),
    };

    try {
      // Offline persistence automatically queues this when the patient is offline.
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('sessions')
          .add(sessionData);
          
      if (kDebugMode) {
        debugPrint('[SESSION LOG] Successfully queued for patient $patientId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SESSION LOG] Failed to write session: $e');
      }
    }
  }
}