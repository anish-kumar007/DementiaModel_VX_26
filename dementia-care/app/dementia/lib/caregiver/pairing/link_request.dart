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

  // 1. Validate against the doc the patient wrote in pairing_codes/{digits}
  final codeSnap = await fs.collection('pairing_codes').doc(clean).get();
  if (!codeSnap.exists) throw LinkError('not-found');
  
  final status = codeSnap.data()?['status'] as String?;
  if (status == 'used') throw LinkError('used');
  if (status == 'expired') throw LinkError('expired');
  if (status != 'active') throw LinkError('not-found');

  // 2. Write request doc; patient screen flips it to 'approved' (10 s timeout)
  final reqRef = fs.collection('pairing_requests').doc();
  try {
    await reqRef.set({
      'code': clean,
      'caregiverUid': caregiverUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final answer = await reqRef.snapshots()
        .firstWhere((s) => (s.data()?['status'] ?? 'pending') != 'pending')
        .timeout(const Duration(seconds: 10));

    final data = answer.data()!;
    
    if (data['status'] == 'approved') {
      final pid = data['pid'] as String;
      final patientName = data['patientName'] as String?;

      // 🔑 CRITICAL FIX: Add this caregiver to the patient's 'caregivers' array.
      // This is exactly what PatientListScreen queries to build the list!
      await fs.collection('patients').doc(pid).update({
        'caregivers': FieldValue.arrayUnion([caregiverUid]),
      });

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