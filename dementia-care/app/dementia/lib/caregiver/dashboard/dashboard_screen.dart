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
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Vibrant Patient Status Banner
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: StatusDot(statusFor(p)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT STATUS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last seen ${timeAgo(toDate(p['lastSeen']))}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (battery != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: battery < 20
                              ? Colors.red.shade700
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              battery < 20
                                  ? Icons.battery_alert
                                  : Icons.battery_charging_full,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$battery%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Urgent/Latest Alerts Card
              _LatestAlerts(pid: pid),
              const SizedBox(height: 16),

              // 3. Colorful Today's Activity Card
              _TodaySessions(pid: pid),
              const SizedBox(height: 24),

              const Text(
                'Quick Navigation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Colorful 2x2 Navigation Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _ColorfulNavTile(
                    icon: Icons.notifications_active,
                    label: 'All Alerts',
                    subtitle: 'Safety & Zones',
                    primaryColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFF7ED),
                    onTap: () => _go(context, AlertsScreen(pid: pid)),
                  ),
                  _ColorfulNavTile(
                    icon: Icons.map_rounded,
                    label: 'Live Map',
                    subtitle: 'GPS Location',
                    primaryColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    onTap: () => _go(context, LiveMapScreen(pid: pid)),
                  ),
                  _ColorfulNavTile(
                    icon: Icons.show_chart_rounded,
                    label: 'Trends',
                    subtitle: 'Daily Activity',
                    primaryColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    onTap: () => _go(context, TrendsScreen(pid: pid)),
                  ),
                  _ColorfulNavTile(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    subtitle: 'Care & Device',
                    primaryColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                    onTap: () => _go(context, SettingsScreen(pid: pid)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  disclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

class _ColorfulNavTile extends StatelessWidget {
  const _ColorfulNavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.primaryColor,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color primaryColor;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withAlpha(80), width: 1.5),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor.withAlpha(180),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D9488).withAlpha(70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Text('Loading activity...');
          final n = snap.data!.docs.length;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: Color(0xFF0F766E),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Cognitive Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n == 0
                          ? 'No memory games played yet today.'
                          : '$n game session${n == 1 ? '' : 's'} completed today!',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22C55E).withAlpha(100)),
            ),
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded,
                    color: Color(0xFF15803D), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All quiet & safe. No recent alerts.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF14532D),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF43F5E).withAlpha(100)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE11D48), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Latest Safety Alerts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF881337),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFFECDD3)),
              for (final d in docs.map((e) => e.data() as Map<String, dynamic>))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      alertIcon(d['type'] as String?),
                      color: alertColor(d['type'] as String?),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    alertLabel(d['type'] as String?),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(timeAgo(toDate(d['time']))),
                  trailing: d['ackedAt'] == null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'OPEN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const Text(
                          'Resolved',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}