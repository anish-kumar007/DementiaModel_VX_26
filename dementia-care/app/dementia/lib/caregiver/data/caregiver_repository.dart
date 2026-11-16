// lib/caregiver/data/caregiver_repository.dart
//
// All caregiver reads and writes live here, so the screens never guess at a
// collection name or a field shape. Mirrors lib/services/patient_writes.dart
// and the rules in firebase/firestore.rules.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../common.dart';

class CaregiverRepo {
  static String get uid => myUid;

  // Reads -------------------------------------------------------------------

  static Stream<QuerySnapshot<Map<String, dynamic>>> myPatients() {
    final id = uid;
    if (id.isEmpty) return const Stream.empty();
    return db
        .collection('patients')
        .where('caregivers', arrayContains: id)
        .snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> patient(String pid) =>
      patientRef(pid).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> sessions(
    String pid, {
    int limit = 200,
  }) =>
      patientSub(pid, 'sessions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> alerts(
    String pid, {
    int limit = 100,
  }) =>
      patientSub(pid, 'alerts')
          .orderBy('time', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> openAlerts(String pid) =>
      patientSub(pid, 'alerts')
          .where('ackedAt', isNull: true)
          .limit(20)
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> locationLogs(
    String pid, {
    int limit = 100,
  }) =>
      patientSub(pid, 'locationLogs')
          .orderBy('time', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> assistantChats(
    String pid, {
    int limit = 30,
  }) =>
      patientSub(pid, 'assistantChats')
          .orderBy('time', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> profileChanges(
    String pid, {
    int limit = 30,
  }) =>
      patientSub(pid, 'profileChanges')
          .orderBy('at', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> reminders(String pid) =>
      patientSub(pid, 'reminders').snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> contacts(String pid) =>
      patientSub(pid, 'contacts').snapshots();

  // Writes ------------------------------------------------------------------

  static Future<void> ackAlert(String pid, String alertId) async {
    final me = uid;
    if (me.isEmpty) throw StateError('Not signed in');
    await patientSub(pid, 'alerts').doc(alertId).update({
      'ackedBy': me,
      'ackedAt': FieldValue.serverTimestamp(),
      'status': 'acked',
    });
  }

  /// Updates patient profile fields and records an audit row.
  static Future<void> saveProfile({
    required String pid,
    required Map<String, dynamic> values,
    required Map<String, dynamic> previous,
  }) async {
    final me = uid;
    if (me.isEmpty) throw StateError('Not signed in');

    final changes = <String, dynamic>{};
    values.forEach((key, value) {
      final before = previous[key];
      if ('${before ?? ''}' != '${value ?? ''}') {
        changes[key] = {'from': before, 'to': value};
      }
    });

    await patientRef(pid).update({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': me,
    });

    if (changes.isNotEmpty) {
      await patientSub(pid, 'profileChanges').add({
        'editorUid': me,
        'editorName': await caregiverName(),
        'editorRole': 'caregiver',
        'at': FieldValue.serverTimestamp(),
        'changes': changes,
      });
    }
  }

  static Future<void> saveSafeZone({
    required String pid,
    required double lat,
    required double lng,
    required int radiusM,
  }) async {
    await patientRef(pid).update({
      'safeZone': {'lat': lat, 'lng': lng, 'radiusM': radiusM},
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  /// Removes only the signed-in caregiver from the patient's caregiver list.
  ///
  /// The list is written explicitly (not with arrayRemove) so the security
  /// rule can verify that exactly one entry, ours, disappeared.
  static Future<void> revokeMyAccess(String pid) async {
    final snap = await patientRef(pid).get();
    final caregivers = (snap.data()?['caregivers'] as List?) ?? const [];
    final remaining = caregivers
        .whereType<String>()
        .where((caregiver) => caregiver != uid)
        .toList();
    await patientRef(pid).update({'caregivers': remaining});
  }

  static Future<void> saveReminder(
    String pid,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final col = patientSub(pid, 'reminders');
    if (id == null) {
      await col.add({...data, 'createdBy': uid});
    } else {
      await col.doc(id).update({...data, 'updatedBy': uid});
    }
  }

  static Future<void> deleteReminder(String pid, String id) =>
      patientSub(pid, 'reminders').doc(id).delete();

  static Future<void> toggleReminder(String pid, String id, bool active) =>
      patientSub(pid, 'reminders').doc(id).update({'active': active});

  static Future<void> saveContact(
    String pid,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final col = patientSub(pid, 'contacts');
    if (id == null) {
      await col.add({...data, 'createdBy': uid});
    } else {
      await col.doc(id).update({...data, 'updatedBy': uid});
    }
  }

  static Future<void> deleteContact(String pid, String id) =>
      patientSub(pid, 'contacts').doc(id).delete();

  /// Stores a caregiver question and its answer so it is visible in the log.
  static Future<void> saveAssistantTurn({
    required String pid,
    required String question,
    required String reply,
    String language = 'en',
  }) async {
    await patientSub(pid, 'assistantChats').add({
      'question': question,
      'reply': reply,
      'language': language,
      'time': FieldValue.serverTimestamp(),
      'source': 'caregiver',
      'by': uid,
    });
  }

  static Future<String> caregiverName() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return 'Caregiver';
    try {
      final doc = await db.collection('users').doc(me.uid).get();
      final name = strOf(doc.data()?['name']);
      if (name.isNotEmpty) return name;
    } catch (_) {
      // fall through to email
    }
    final email = me.email ?? '';
    return email.isEmpty ? 'Caregiver' : email.split('@').first;
  }
}
