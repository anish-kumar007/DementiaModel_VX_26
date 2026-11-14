// app/lib/caregiver/dashboard/dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../alerts/alerts_screen.dart';
import '../common.dart';
import '../map/live_map_screen.dart';
import '../settings/settings_screen.dart';
import '../trends/trends_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.pid});
  final String pid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: patientRef(pid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Could not load this patient.')));
        }
        if (!snap.hasData) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final p = (snap.data!.data() as Map<String, dynamic>?) ?? {};
        final name = (p['name'] as String?) ?? 'Patient';
        final battery = (p['battery'] as num?)?.toInt();

        return Scaffold(
          appBar: AppBar(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            elevation: 2,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Urgent/Latest Alerts pinned to top for immediate safety awareness
              _LatestAlerts(pid: pid),
              const SizedBox(height: 12),
              
              // Patient Status Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      StatusDot(statusFor(p)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last seen ${timeAgo(toDate(p['lastSeen']))}',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                            ),
                            if (battery != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Device Battery: $battery%',
                                style: TextStyle(
                                  color: battery < 20 ? Colors.red : Colors.grey[700],
                                  fontWeight: battery < 20 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _TodaySessions(pid: pid),
              const SizedBox(height: 24),
              
              const Text(
                'Quick Navigation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              
              _NavButton(
                icon: Icons.notifications_active,
                label: 'All alerts',
                onTap: () => _go(context, AlertsScreen(pid: pid)),
              ),
              _NavButton(
                icon: Icons.map,
                label: 'Live map & Location',
                onTap: () => _go(context, LiveMapScreen(pid: pid)),
              ),
              _NavButton(
                icon: Icons.show_chart,
                label: 'Engagement trends',
                onTap: () => _go(context, TrendsScreen(pid: pid)),
              ),
              _NavButton(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () => _go(context, SettingsScreen(pid: pid)),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  disclaimer,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _go(BuildContext c, Widget w) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));
}

class _NavButton extends StatelessWidget {
  const _NavButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          height: 60,
          child: FilledButton.tonalIcon(
            onPressed: onTap,
            icon: Icon(icon, size: 28),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}

class _TodaySessions extends StatelessWidget {
  const _TodaySessions({required this.pid});
  final String pid;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final stream = patientRef(pid)
        .collection('sessions')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();
    return InfoCard(
      title: 'Today\'s activity',
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Text('Loading...');
          final n = snap.data!.docs.length;
          return Text(
            n == 0
                ? 'No games played yet today.'
                : '$n game session${n == 1 ? '' : 's'} completed today.',
            style: const TextStyle(fontSize: 15),
          );
        },
      ),
    );
  }
}

class _LatestAlerts extends StatelessWidget {
  const _LatestAlerts({required this.pid});
  final String pid;
  @override
  Widget build(BuildContext context) {
    final stream = patientRef(pid)
        .collection('alerts')
        .orderBy('time', descending: true)
        .limit(3)
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Card(
            color: Colors.green[50],
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text('All quiet. No recent alerts.', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }
        
        return Card(
          elevation: 2,
          color: Colors.orange[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Alerts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                for (final d in docs.map((e) => e.data() as Map<String, dynamic>))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(alertIcon(d['type'] as String?),
                        color: alertColor(d['type'] as String?)),
                    title: Text(alertLabel(d['type'] as String?),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(timeAgo(toDate(d['time']))),
                    trailing: d['ackedAt'] == null
                        ? const Chip(
                            label: Text('Open', style: TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: Colors.red,
                            visualDensity: VisualDensity.compact,
                          )
                        : const Text('Acknowledged', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}