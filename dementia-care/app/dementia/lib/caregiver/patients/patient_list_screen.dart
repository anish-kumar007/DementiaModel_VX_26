// app/lib/caregiver/patients/patient_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../dashboard/dashboard_screen.dart';
import '../pairing/pairing_screen.dart';

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = db
        .collection('patients')
        .where('caregivers', arrayContains: myUid)
        .snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load patients.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No one linked yet.\nTap "Link a patient" and enter the 6-digit code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final d in docs) _PatientTile(pid: d.id, data: d.data()),
              const SizedBox(height: 12),
              Center(
                  child: Text(disclaimer,
                      style: Theme.of(context).textTheme.bodySmall)),
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
    // Red if any recent alert has not been acknowledged yet. Checked on the
    // phone so it works even if the patient app leaves ackedAt out of the doc.
    final recent = patientRef(pid)
        .collection('alerts')
        .orderBy('time', descending: true)
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recent,
      builder: (context, snap) {
        final hasOpen = (snap.data?.docs ?? [])
            .any((d) => d.data()['ackedAt'] == null);
        final status = statusFor(data, openAlert: hasOpen);
        final battery = (data['battery'] as num?)?.toInt();
        return Card(
          child: ListTile(
            minVerticalPadding: 16,
            leading: StatusDot(status, size: 22),
            title: Text(data['name'] ?? 'Patient',
                style: Theme.of(context).textTheme.titleLarge),
            subtitle: Text(
              'Last seen ${timeAgo(toDate(data['lastSeen']))}'
              '${battery != null ? '  ·  Battery $battery%' : ''}'
              '${hasOpen ? '\nNeeds attention' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DashboardScreen(pid: pid)),
            ),
          ),
        );
      },
    );
  }
}