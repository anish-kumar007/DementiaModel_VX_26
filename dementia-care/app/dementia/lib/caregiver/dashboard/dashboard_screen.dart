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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        final p = snap.data!.data() ?? {};
        final name = (p['name'] as String?) ?? 'Patient';
        final battery = (p['battery'] as num?)?.toInt();

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InfoCard(
                title: 'Status',
                child: Row(
                  children: [
                    StatusDot(statusFor(p)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Last seen ${timeAgo(toDate(p['lastSeen']))}'
                        '${battery != null ? '\nBattery $battery%' : ''}',
                      ),
                    ),
                  ],
                ),
              ),
              _TodaySessions(pid: pid),
              _LatestAlerts(pid: pid),
              const SizedBox(height: 8),
              _NavButton(
                icon: Icons.notifications_active,
                label: 'All alerts',
                onTap: () => _go(context, AlertsScreen(pid: pid)),
              ),
              _NavButton(
                icon: Icons.map,
                label: 'Live map',
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
              const SizedBox(height: 16),
              Center(
                  child: Text(disclaimer,
                      style: Theme.of(context).textTheme.bodySmall)),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 56,
          child: FilledButton.tonalIcon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 18)),
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
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Text('Loading...');
          final n = snap.data!.docs.length;
          return Text(n == 0
              ? 'No games played yet today.'
              : '$n game session${n == 1 ? '' : 's'} today.');
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
    return InfoCard(
      title: 'Latest alerts',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Text('Loading...');
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Text('No alerts. All quiet.');
          return Column(
            children: [
              for (final d in docs.map((e) => e.data()))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(alertIcon(d['type'] as String?),
                      color: alertColor(d['type'] as String?)),
                  title: Text(alertLabel(d['type'] as String?)),
                  subtitle: Text(timeAgo(toDate(d['time']))),
                  trailing: d['ackedAt'] == null
                      ? const Text('Open',
                          style: TextStyle(fontWeight: FontWeight.bold))
                      : const Text('Acknowledged'),
                ),
            ],
          );
        },
      ),
    );
  }
}