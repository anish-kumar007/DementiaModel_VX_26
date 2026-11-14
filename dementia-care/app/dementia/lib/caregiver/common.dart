// app/lib/caregiver/common.dart
// Shared helpers for the caregiver module. Self-contained so it compiles even
// before B's shared widgets land. Swap StatusDot/InfoCard for B's versions later.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

final FirebaseFirestore db = FirebaseFirestore.instance;

String get myUid => FirebaseAuth.instance.currentUser!.uid;

DocumentReference<Map<String, dynamic>> patientRef(String pid) =>
    db.collection('patients').doc(pid);

/// Status colours for a patient: green = fine, amber = stale/low battery,
/// red = unacknowledged SOS or geofence alert.
enum PatientStatus { ok, warn, alert }

Color statusColor(PatientStatus s) {
  switch (s) {
    case PatientStatus.ok:
      return const Color(0xFF2E7D32);
    case PatientStatus.warn:
      return const Color(0xFFF9A825);
    case PatientStatus.alert:
      return const Color(0xFFC62828);
  }
}

DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

String timeAgo(DateTime? t) {
  if (t == null) return 'no data yet';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Works out the status colour from the patient doc (alerts are checked on the
/// patient list through a separate query).
PatientStatus statusFor(Map<String, dynamic> p, {bool openAlert = false}) {
  if (openAlert) return PatientStatus.alert;
  final seen = toDate(p['lastSeen']);
  final battery = (p['battery'] as num?)?.toInt();
  final stale = seen == null || DateTime.now().difference(seen).inMinutes > 30;
  final low = battery != null && battery <= 15;
  return (stale || low) ? PatientStatus.warn : PatientStatus.ok;
}

class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 16});
  final PatientStatus status;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: statusColor(status), shape: BoxShape.circle),
      );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );
}

void snack(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

/// Wording rule from the brief: always show this on key screens.
const String disclaimer =
    'Not a medical device. Designed to complement clinical care.';