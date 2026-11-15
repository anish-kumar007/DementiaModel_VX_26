import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart'; // Assumes toDate() and timeAgo() are here
import '../map/live_map_screen.dart';

// --- Helpers (Defined here so push_handler can safely import them if needed) ---
String alertLabel(String? type) {
  switch (type) {
    case 'sos': return 'SOS pressed';
    case 'geofence': return 'Left the safe zone';
    case 'offline': return 'Phone offline for a while';
    case 'lowBattery': return 'Battery is low';
    default: return 'Alert';
  }
}

IconData alertIcon(String? type) {
  switch (type) {
    case 'sos': return Icons.sos;
    case 'geofence': return Icons.wrong_location;
    case 'offline': return Icons.wifi_off;
    case 'lowBattery': return Icons.battery_alert;
    default: return Icons.notifications;
  }
}

Color alertColor(String? type) {
  switch (type) {
    case 'sos': return const Color(0xFFC62828);
    case 'geofence': return const Color(0xFFEF6C00);
    default: return const Color(0xFFF9A825);
  }
}
// --------------------------------------------------------------------------------

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.pid, this.highlightId});
  final String pid;
  final String? highlightId;

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
            itemBuilder: (_, i) {
              final doc = docs[i];
              return _AlertCard(
                pid: pid,
                doc: doc,
                highlight: doc.id == highlightId,
              );
            },
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.pid, required this.doc, required this.highlight});
  final String pid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool highlight;

  Future<void> _ack(BuildContext context) async {
    try {
      // FUNCTIONAL FIX: Get UID directly from FirebaseAuth to guarantee it works
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to acknowledge.')),
          );
        }
        return;
      }

      await doc.reference.update({
        'ackedBy': currentUid,
        'ackedAt': FieldValue.serverTimestamp(),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert acknowledged'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not acknowledge: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final type = d['type'] as String?;
    final acked = d['ackedAt'] != null;
    final loc = d['location'] as Map<String, dynamic>?;
    // FUNCTIONAL FIX: Safe null checking for nested map values
    final hasLoc = loc != null && loc['lat'] != null && loc['lng'] != null;

    return Card(
      elevation: highlight ? 4 : 1,
      shape: highlight
          ? RoundedRectangleBorder(
              side: BorderSide(color: alertColor(type) ?? Colors.grey, width: 3),
              borderRadius: BorderRadius.circular(12))
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(alertIcon(type), color: alertColor(type), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alertLabel(type),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      // FUNCTIONAL FIX: Safe fallback if 'time' is missing
                      Text(timeAgo(toDate(d['time']) ?? DateTime.now())),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (acked)
              Text(
                'Acknowledged ${timeAgo(toDate(d['ackedAt']) ?? DateTime.now())}',
                style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => _ack(context),
                        child: const Text('Acknowledge', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  if (hasLoc) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map),
                        label: const Text('Map'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LiveMapScreen(pid: pid)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}