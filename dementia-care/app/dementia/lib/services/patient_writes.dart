// lib/services/patient_writes.dart
//
// The single place where the patient app writes data the caregiver app reads.
// Field names here are the contract with lib/caregiver (see firebase/firestore.rules).
//
// patients/{pid}
//   name, preferredName, age, bloodGroup, languages, homeAddress, diagnosis,
//   allergies, medications, doctorName, doctorPhone, caregiverName,
//   caregiverRelation, caregiverPhone, comfortPreferences
//   caregivers: [uid]
//   safeZone: {lat, lng, radiusM}
//   locationSharingEnabled: bool
//   lastLocation: {lat, lng, accuracy, time(ms)}
//   battery: int, lastSeen: Timestamp, lastActiveAt: Timestamp
// patients/{pid}/sessions      {game, level, accuracy, avgResponseMs, language,
//                               timestamp, score, rounds, durationMs}
// patients/{pid}/locationLogs  {lat, lng, accuracy, battery, time, source}
// patients/{pid}/alerts        {type, time, status, message, location, ackedBy, ackedAt}
// patients/{pid}/assistantChats{question, reply, language, time, source}
// patients/{pid}/profileChanges{editorUid, editorName, editorRole, at, changes}

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../features/patients/services/location_service.dart';

class PatientWrites {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Battery _battery = Battery();

  static String? get pid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? _doc(String? patientId) {
    final id = patientId ?? pid;
    if (id == null || id.isEmpty) return null;
    return _db.collection('patients').doc(id);
  }

  /// Writes the live location block plus one row in the location log.
  /// Firestore's offline cache queues this when there is no network.
  static Future<void> recordLocation({
    required double lat,
    required double lng,
    double? accuracy,
    int? battery,
    String source = 'auto',
    String? patientId,
    bool appendLog = true,
    bool touchSeen = true,
  }) async {
    final doc = _doc(patientId);
    if (doc == null) return;
    final now = DateTime.now();
    final data = <String, dynamic>{
      'lastLocation': {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'time': now.millisecondsSinceEpoch,
      },
      'lastActiveAt': Timestamp.fromDate(now),
      if (battery != null) 'battery': battery,
      if (touchSeen) 'lastSeen': Timestamp.fromDate(now),
    };

    try {
      await doc.set(data, SetOptions(merge: true));
      if (appendLog) {
        await doc.collection('locationLogs').add({
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
          'battery': battery,
          'time': Timestamp.fromDate(now),
          'source': source,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PATIENT WRITES] location failed: $e');
    }
  }

  /// Reads the patient's own sharing consent. Defaults to true when unset.
  static Future<bool> locationSharingEnabled(String? patientId) async {
    final doc = _doc(patientId);
    if (doc == null) return false;
    try {
      final snap = await doc.get();
      return (snap.data()?['locationSharingEnabled'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Creates an alert the caregiver sees in the alert log.
  static Future<bool> logAlert({
    required String type,
    String message = '',
    String severity = 'high',
    double? lat,
    double? lng,
    double? accuracy,
    String? patientId,
    Map<String, dynamic> extra = const {},
  }) async {
    final doc = _doc(patientId);
    if (doc == null) return false;
    try {
      await doc.collection('alerts').add({
        'type': type,
        'status': 'open',
        'severity': severity,
        'message': message,
        // Every reader sorts on `time`; keep it a Timestamp in one place only.
        'time': Timestamp.fromDate(DateTime.now()),
        if (lat != null && lng != null)
          'location': {
            'lat': lat,
            'lng': lng,
            if (accuracy != null) 'accuracy': accuracy,
          },
        'ackedBy': null,
        'ackedAt': null,
        ...extra,
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[PATIENT WRITES] alert failed: $e');
      return false;
    }
  }

  /// One turn of the patient's voice assistant, mirrored for the caregiver.
  static Future<void> logAssistantTurn({
    required String question,
    required String reply,
    required String language,
    String? patientId,
    String source = 'patient',
  }) async {
    final doc = _doc(patientId);
    if (doc == null) return;
    try {
      await doc.collection('assistantChats').add({
        'question': question,
        'reply': reply,
        'language': language,
        'time': Timestamp.fromDate(DateTime.now()),
        'source': source,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[PATIENT WRITES] assistant chat failed: $e');
    }
  }

  /// Audit row so a caregiver can see who changed what on the profile.
  static Future<void> logProfileChange({
    required Map<String, dynamic> changes,
    required String editorUid,
    required String editorName,
    required String editorRole,
    String? patientId,
  }) async {
    if (changes.isEmpty) return;
    final doc = _doc(patientId);
    if (doc == null) return;
    try {
      await doc.collection('profileChanges').add({
        'editorUid': editorUid,
        'editorName': editorName,
        'editorRole': editorRole,
        'at': Timestamp.fromDate(DateTime.now()),
        'changes': changes,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[PATIENT WRITES] profile audit failed: $e');
    }
  }

  /// Battery level, used when a location fix is unavailable.
  static Future<int?> batteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }
}

/// Foreground location sharing while the patient app is open.
/// Uploads every [interval] and whenever the patient presses SOS.
class PatientTelemetry {
  static Timer? _timer;
  static bool _busy = false;

  static bool get isRunning => _timer != null;

  static void start({Duration interval = const Duration(minutes: 3)}) {
    if (_timer != null) return;
    // First reading quickly, then on a gentle interval to save battery.
    Timer(const Duration(seconds: 5), () => pushOnce());
    _timer = Timer.periodic(interval, (_) => pushOnce());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> pushOnce({String source = 'auto'}) async {
    if (_busy) return;
    _busy = true;
    try {
      final enabled = await PatientWrites.locationSharingEnabled(null);
      if (!enabled) return;

      final payload = await LocationService.getFilteredLocationPayload();
      if (payload == null) {
        // No fix: still keep "last seen" honest with a battery reading.
        final doc = PatientWrites.pid;
        if (doc == null) return;
        final battery = await PatientWrites.batteryLevel();
        await FirebaseFirestore.instance.collection('patients').doc(doc).set({
          'lastActiveAt': Timestamp.fromDate(DateTime.now()),
          if (battery != null) 'battery': battery,
        }, SetOptions(merge: true));
        return;
      }

      final loc = payload['lastLocation'] as Map<String, dynamic>;
      await PatientWrites.recordLocation(
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
        accuracy: (loc['accuracy'] as num?)?.toDouble(),
        battery: (payload['battery'] as num?)?.toInt(),
        source: source,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TELEMETRY] push failed: $e');
    } finally {
      _busy = false;
    }
  }
}
