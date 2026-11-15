import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

import '../common.dart';
import '../dashboard/dashboard_screen.dart';
import '../pairing/pairing_screen.dart';

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get the current user ID safely
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // If not logged in, show a message instead of crashing the query
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your family.')),
      );
    }

    // 2. The Query: Find all patients where 'caregivers' array contains my UID
    final stream = FirebaseFirestore.instance
        .collection('patients')
        .where('caregivers', arrayContains: currentUid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('My family')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          // 3. Show the ACTUAL error if it fails (Permission denied, etc.)
          if (snap.hasError) {
            debugPrint('patients query failed: ${snap.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading patients:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          
          // 4. Empty List State
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No patients linked yet.\nTap "Link a patient" to add one.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }

          // 5. The List of Patients
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final d in docs) _PatientTile(pid: d.id, data: d.data()),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.link),
        label: const Text('Link a patient'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PairingScreen()),
        ),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.pid, required this.data});
  final String pid;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 16,
        title: Text(data['name'] ?? 'Patient',
            style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text('ID: $pid'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DashboardScreen(pid: pid)),
        ),
      ),
    );
  }
}