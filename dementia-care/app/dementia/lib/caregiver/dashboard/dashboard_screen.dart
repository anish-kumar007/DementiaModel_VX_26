// lib/caregiver/dashboard/dashboard_screen.dart
//
// The patient screen every caregiver lands on after pairing: an overview plus
// tabs for activity, location, alerts and the remaining care tools.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/reminder_utils.dart';
import '../activity/session_log_screen.dart';
import '../alerts/alerts_screen.dart';
import '../assistant/assistant_screen.dart';
import '../common.dart';
import '../data/caregiver_repository.dart';
import '../location/location_log_screen.dart';
import '../map/live_map_screen.dart';
import '../profile/patient_profile_editor_screen.dart';
import '../settings/contacts_screen.dart';
import '../settings/reminders_screen.dart';
import '../settings/safe_zone_screen.dart';
import '../trends/trends_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Cg.surface,
        appBar: AppBar(
          backgroundColor: Cg.navy,
          foregroundColor: Colors.white,
          title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: CaregiverRepo.patient(pid),
            builder: (context, snap) {
              final patient = snap.data?.data() ?? <String, dynamic>{};
              final name = strOf(patient['name'], 'Patient');
              final status = statusFor(patient);
              return Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: statusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              );
            },
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFBFD3F5),
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Activity'),
              Tab(text: 'Location'),
              Tab(text: 'Alerts'),
              Tab(text: 'More'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(pid: pid),
            ActivityView(pid: pid),
            LocationView(pid: pid),
            AlertsView(pid: pid),
            _MoreTab(pid: pid),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.patient(pid),
      builder: (context, patientSnap) {
        if (patientSnap.hasError) {
          return _Message(text: friendlyError(patientSnap.error!));
        }
        if (!patientSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final patient = patientSnap.data!.data() ?? <String, dynamic>{};
        final location = PatientLocation.fromPatient(patient);
        final battery = intOf(patient['battery']);
        final seen = dateField(patient, 'lastSeen');

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: CaregiverRepo.openAlerts(pid),
          builder: (context, alertSnap) {
            final openAlerts = (alertSnap.data?.docs ?? [])
                .where((d) => isOpenAlert(d.data()))
                .toList();
            final status = statusFor(patient, openAlert: openAlerts.isNotEmpty);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusBanner(
                  patient: patient,
                  status: status,
                  seen: seen,
                  battery: battery,
                  location: location,
                  openAlerts: openAlerts.length,
                ),
                const SizedBox(height: 14),
                _TodayCard(pid: pid),
                const SizedBox(height: 14),
                _DailyBriefingCard(pid: pid),
                const SizedBox(height: 14),
                _ProfileSnapshot(pid: pid, patient: patient),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    disclaimer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Cg.muted),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.patient,
    required this.status,
    required this.seen,
    required this.battery,
    required this.location,
    required this.openAlerts,
  });

  final Map<String, dynamic> patient;
  final PatientStatus status;
  final DateTime? seen;
  final int? battery;
  final PatientLocation location;
  final int openAlerts;

  @override
  Widget build(BuildContext context) {
    final name = strOf(patient['name'], 'Patient');
    final preferred = strOf(patient['preferredName']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Cg.navy, Cg.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (preferred.isNotEmpty)
                      Text(
                        'Prefers “$preferred”',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status == PatientStatus.alert
                            ? const Color(0xFFFF8A8A)
                            : (status == PatientStatus.ok
                                ? const Color(0xFF7BE2A6)
                                : const Color(0xFFFFD166)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BannerChip(icon: Icons.schedule, label: 'Seen ${timeAgo(seen)}'),
              if (battery != null)
                _BannerChip(
                  icon: battery! <= 15
                      ? Icons.battery_alert
                      : Icons.battery_std,
                  label: '$battery%',
                ),
              if (location.insideZone != null)
                _BannerChip(
                  icon: location.insideZone!
                      ? Icons.shield
                      : Icons.wrong_location,
                  label: location.insideZone!
                      ? 'Inside safe zone'
                      : 'Outside safe zone',
                ),
              if (openAlerts > 0)
                _BannerChip(
                  icon: Icons.warning_amber_rounded,
                  label: '$openAlerts open alert${openAlerts == 1 ? '' : 's'}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.sessions(pid, limit: 50),
      builder: (context, sessionSnap) {
        final sessions = sessionSnap.data?.docs ?? [];
        final today = sessions.where((d) {
          final t = toDate(d.data()['timestamp']);
          final now = DateTime.now();
          return t != null &&
              t.year == now.year &&
              t.month == now.month &&
              t.day == now.day;
        }).toList();

        double avg = 0;
        if (today.isNotEmpty) {
          avg = today.fold<double>(
                0,
                (sum, d) => sum + accuracyPct(d.data()['accuracy']),
              ) /
              today.length;
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: CaregiverRepo.reminders(pid),
          builder: (context, reminderSnap) {
            final reminderDocs = reminderSnap.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final reminders = <Map<String, dynamic>>[
              for (final d in reminderDocs) d.data(),
            ];
            final next = ReminderTime.next(reminders);

            return InfoCard(
              title: 'Today',
              icon: Icons.today,
              accent: Cg.teal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line(
                    icon: Icons.sports_esports,
                    text: today.isEmpty
                        ? 'No game session yet today.'
                        : '${today.length} session${today.length == 1 ? '' : 's'} '
                            'played · ${avg.round()}% average accuracy.',
                  ),
                  _Line(
                    icon: Icons.alarm,
                    text: next == null
                        ? (reminders.isEmpty
                            ? 'No reminders set.'
                            : 'All reminders for today have passed.')
                        : 'Next reminder ${ReminderTime.to12h(next['time'] as String?)} · '
                            '${strOf(next['title'], 'reminder')}',
                  ),
                  _Line(
                    icon: Icons.history,
                    text: sessions.isEmpty
                        ? 'No sessions recorded yet.'
                        : 'Last session ${timeAgo(toDate(sessions.first.data()['timestamp']))}.',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DailyBriefingCard extends StatelessWidget {
  const _DailyBriefingCard({required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Cg.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Cg.violet),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Care assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Cg.ink,
                  ),
                ),
                Text(
                  'Ask for a briefing, alerts, games or trends. Answers come '
                  'from the records, not from a diagnosis.',
                  style: TextStyle(fontSize: 12, color: Cg.slate, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cg.violet),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CareAssistantScreen(pid: pid)),
            ),
            child: const Text('Ask'),
          ),
        ],
      ),
    );
  }
}

class _ProfileSnapshot extends StatelessWidget {
  const _ProfileSnapshot({required this.pid, required this.patient});

  final String pid;
  final Map<String, dynamic> patient;

  @override
  Widget build(BuildContext context) {
    final fields = <String, String>{
      'Age': strOf(patient['age']),
      'Blood group': strOf(patient['bloodGroup']),
      'Allergies': strOf(patient['allergies']),
      'Medications': strOf(patient['medications']),
      'Doctor': [
        strOf(patient['doctorName']),
        strOf(patient['doctorPhone']),
      ].where((v) => v.isNotEmpty).join(' · '),
      'Primary caregiver': [
        strOf(patient['caregiverName']),
        strOf(patient['caregiverRelation']),
      ].where((v) => v.isNotEmpty).join(' · '),
    };

    return InfoCard(
      title: 'Care profile',
      icon: Icons.badge_outlined,
      trailing: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PatientProfileEditorScreen(pid: pid)),
        ),
        child: const Text('Edit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in fields.entries)
            if (entry.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12, color: Cg.slate),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 13, color: Cg.ink),
                      ),
                    ),
                  ],
                ),
              ),
          if (fields.values.every((v) => v.isEmpty))
            const Text(
              'The care profile is empty. Fill it in so the important details '
              'are one tap away.',
              style: TextStyle(fontSize: 12, color: Cg.slate),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More
// ---------------------------------------------------------------------------

Future<void> _revokeAccess(BuildContext context, String pid) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove my access?'),
      content: const Text(
        'You will stop seeing this patient\'s status, sessions, location and '
        'alerts. They can link you again later with a new code.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Cg.red),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove access'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await CaregiverRepo.revokeMyAccess(pid);
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  } catch (e) {
    if (context.mounted) snack(context, friendlyError(e));
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    void push(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoCard(
          title: 'Care tools',
          icon: Icons.apps,
          child: Column(
            children: [
              _MoreTile(
                icon: Icons.trending_up,
                color: Cg.teal,
                title: 'Engagement trends',
                subtitle: 'Change from this patient\'s own baseline',
                onTap: () => push(TrendsScreen(pid: pid)),
              ),
              _MoreTile(
                icon: Icons.badge,
                color: Cg.navy,
                title: 'Patient profile',
                subtitle: 'Care details and the change log',
                onTap: () => push(PatientProfileEditorScreen(pid: pid)),
              ),
            ],
          ),
        ),
        InfoCard(
          title: 'Care settings',
          icon: Icons.tune,
          accent: Cg.amber,
          child: Column(
            children: [
              _MoreTile(
                icon: Icons.shield_outlined,
                color: Cg.green,
                title: 'Safe zone',
                subtitle: 'Centre and radius of the safe area',
                onTap: () => push(SafeZoneScreen(pid: pid)),
              ),
              _MoreTile(
                icon: Icons.alarm,
                color: Cg.amber,
                title: 'Reminders',
                subtitle: 'Medication, water, games',
                onTap: () => push(RemindersScreen(pid: pid)),
              ),
              _MoreTile(
                icon: Icons.contacts,
                color: Cg.blue,
                title: 'Contacts and doctor',
                subtitle: 'Who the patient can call',
                onTap: () => push(ContactsScreen(pid: pid)),
              ),
            ],
          ),
        ),
        InfoCard(
          title: 'Your access',
          icon: Icons.lock_outline,
          accent: Cg.red,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The patient controls location sharing from their own phone. '
                'Removing your access only removes your account; other '
                'caregivers keep theirs.',
                style: TextStyle(fontSize: 12, color: Cg.slate, height: 1.4),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Cg.red,
                    side: const BorderSide(color: Cg.red),
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: () => _revokeAccess(context, pid),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Remove my access'),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Text(
            disclaimer,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Cg.muted),
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Cg.ink),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Cg.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Cg.slate, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
