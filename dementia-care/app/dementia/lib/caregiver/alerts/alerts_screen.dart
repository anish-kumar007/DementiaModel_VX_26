// app/lib/caregiver/alerts/alerts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../map/live_map_screen.dart';

String alertLabel(String? type) {
  switch (type) {
    case 'sos':
      return 'SOS pressed';
    case 'geofence':
      return 'Left the safe zone';
    case 'offline':
      return 'Phone offline for a while';
    case 'lowBattery':
      return 'Battery is low';
    default:
      return 'Alert';
  }
}

IconData alertIcon(String? type) {
  switch (type) {
    case 'sos':
      return Icons.sos;
    case 'geofence':
      return Icons.wrong_location;
    case 'offline':
      return Icons.wifi_off;
    case 'lowBattery':
      return Icons.battery_alert;
    default:
      return Icons.notifications;
  }
}

Color alertColor(String? type) {
  switch (type) {
    case 'sos':
      return const Color(0xFFC62828);
    case 'geofence':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFFF9A825);
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.pid, this.highlightId});
  final String pid;
  final String? highlightId; // set when opened from a push notification

  @override
  Widget build(BuildContext context) {
    final stream = patientRef(pid)
        .collection('alerts')
        .orderBy('time', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load alerts.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No alerts. All quiet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) => _AlertCard(
              pid: pid,
              doc: docs[i],
              highlight: docs[i].id == highlightId,
            ),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard(
      {required this.pid, required this.doc, required this.highlight});
  final String pid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool highlight;

  Future<void> _ack(BuildContext context) async {
    try {
      // Only these two fields; the security rules allow nothing else.
      await doc.reference.update({
        'ackedBy': myUid,
        'ackedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (context.mounted) snack(context, 'Could not acknowledge. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final type = d['type'] as String?;
    final acked = d['ackedAt'] != null;
    final loc = d['location'] as Map<String, dynamic>?;
    final hasLoc = loc != null && loc['lat'] != null && loc['lng'] != null;

    return Card(
      shape: highlight
          ? RoundedRectangleBorder(
              side: BorderSide(color: alertColor(type), width: 3),
              borderRadius: BorderRadius.circular(12))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(alertIcon(type), color: alertColor(type), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alertLabel(type),
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(timeAgo(toDate(d['time']))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (acked)
              Text('Acknowledged ${timeAgo(toDate(d['ackedAt']))}',
                  style: const TextStyle(color: Color(0xFF2E7D32)))
            else
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _ack(context),
                      child: const Text('Acknowledge',
                          style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
                if (hasLoc) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Map'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => LiveMapScreen(pid: pid)),
                      ),
                    ),
                  ),
                ],
              ]),
          ],
        ),
      ),
    );
  }
}