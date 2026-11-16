// lib/caregiver/patients/patient_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../dashboard/dashboard_screen.dart';
import '../data/caregiver_repository.dart';
import '../pairing/pairing_screen.dart';

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  void _openPairing(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PairingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('My family'),
        actions: [
          IconButton(
            tooltip: 'Link a patient',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _openPairing(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CaregiverRepo.myPatients(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  friendlyError(snap.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.family_restroom, size: 56, color: Cg.muted),
                const SizedBox(height: 12),
                const Text(
                  'No patient linked yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Cg.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Open the patient app, tap the link icon and read out the '
                  '6-digit code. It works once and expires in 10 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Cg.slate, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Cg.navy,
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: () => _openPairing(context),
                  icon: const Icon(Icons.link),
                  label: const Text('Enter a pairing code'),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final doc in docs)
                _PatientCard(pid: doc.id, patient: doc.data()),
              const SizedBox(height: 8),
              Text(
                'Status is inferred from the last check-in and battery. '
                'Open a patient to see sessions, alerts and location.',
                style: TextStyle(fontSize: 11, color: Cg.muted),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.link),
        label: const Text('Link a patient'),
        onPressed: () => _openPairing(context),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.pid, required this.patient});

  final String pid;
  final Map<String, dynamic> patient;

  String get _initials {
    final name = strOf(patient['name'], '?');
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.openAlerts(pid),
      builder: (context, alertSnap) {
        final openAlerts = alertSnap.data?.docs.where(
              (d) => isOpenAlert(d.data()),
            ).length ??
            0;
        final status = statusFor(patient, openAlert: openAlerts > 0);
        final name = strOf(patient['name'], 'Patient');
        final preferred = strOf(patient['preferredName']);
        final battery = intOf(patient['battery']);
        final seen = dateField(patient, 'lastSeen');
        final age = strOf(patient['age']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: status == PatientStatus.alert
                  ? Cg.red.withValues(alpha: 0.4)
                  : Cg.cardBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DashboardScreen(pid: pid)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor(status).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Cg.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(status: status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (preferred.isNotEmpty) '“$preferred”',
                            if (age.isNotEmpty) 'Age $age',
                            'seen ${timeAgo(seen)}',
                            if (battery != null) 'battery $battery%',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: Cg.slate),
                        ),
                        if (openAlerts > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Cg.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$openAlerts open alert${openAlerts == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Cg.red,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Cg.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
