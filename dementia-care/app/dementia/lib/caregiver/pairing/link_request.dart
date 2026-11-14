import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LinkError implements Exception {
  LinkError(this.code);
  final String code; // 'not-found' | 'expired' | 'used' | 'locked' | 'denied'
}

class LinkResult {
  LinkResult(this.pid, this.name);
  final String pid;
  final String? name;
}

Future<LinkResult> requestLink(String code) async {
  final fs = FirebaseFirestore.instance;
  final clean = code.replaceAll(RegExp(r'\D'), '');
  if (clean.length != 6) throw LinkError('not-found');

  final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
  if (caregiverUid == null) throw LinkError('denied');

  // 1. Validate the code the patient recorded.
  final codeSnap = await fs.collection('pairing_codes').doc(clean).get();
  if (!codeSnap.exists) throw LinkError('not-found');

  final status = codeSnap.data()?['status'] as String?;
  if (status == 'used') throw LinkError('used');
  if (status == 'expired') throw LinkError('expired');
  if (status != 'active') throw LinkError('not-found');

  // 2. Write the request; the patient flips it to 'approved' (10 s timeout).
  final reqRef = fs.collection('pairing_requests').doc();
  try {
    await reqRef.set({
      'code': clean,
      'caregiverUid': caregiverUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final answer = await reqRef
        .snapshots()
        .firstWhere((s) => (s.data()?['status'] ?? 'pending') != 'pending')
        .timeout(const Duration(seconds: 10));

    final data = answer.data()!;

    if (data['status'] == 'approved') {
      // ✅ Declare the locals here so 'pid' and 'patientName' are defined.
      final pid = data['pid'] as String;
      final patientName = data['patientName'] as String?;

      // No patients.update here — the patient adds the caregiver to their
      // own doc (owner-only write) inside pairing_code_screen.dart.
      return LinkResult(pid, patientName);
    }

    if (data['status'] == 'denied') throw LinkError('denied');
    throw LinkError('not-found');
  } on TimeoutException {
    await reqRef.delete().catchError((_) {});
    rethrow;
  } catch (e) {
    if (e is! LinkError) await reqRef.delete().catchError((_) {});
    rethrow;
  }
}