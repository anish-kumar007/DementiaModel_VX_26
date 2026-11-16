// lib/caregiver/common.dart
//
// Shared helpers for the caregiver module: Firestore references, formatting,
// status colours and alert metadata. Every caregiver screen imports this.
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

final FirebaseFirestore db = FirebaseFirestore.instance;

String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

DocumentReference<Map<String, dynamic>> patientRef(String pid) =>
    db.collection('patients').doc(pid);

CollectionReference<Map<String, dynamic>> patientSub(String pid, String name) =>
    patientRef(pid).collection(name);

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

class Cg {
  static const ink = Color(0xFF0F172A);
  static const slate = Color(0xFF475569);
  static const muted = Color(0xFF94A3B8);
  static const navy = Color(0xFF1E3A8A);
  static const blue = Color(0xFF3B82F6);
  static const teal = Color(0xFF0F766E);
  static const green = Color(0xFF15803D);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFE11D48);
  static const violet = Color(0xFF7C3AED);
  static const surface = Color(0xFFF4F6FA);
  static const cardBorder = Color(0xFFE2E8F0);
}

// ---------------------------------------------------------------------------
// Value helpers
// ---------------------------------------------------------------------------

DateTime? toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String) return DateTime.tryParse(v);
  return null;
}

DateTime? dateField(Map<String, dynamic>? m, String key) =>
    m == null ? null : toDate(m[key]);

double? numOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? intOf(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String strOf(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

/// Accuracy may be stored as 0-1 or 0-100. Always show 0-100.
double accuracyPct(dynamic v) {
  final n = numOf(v);
  if (n == null) return 0;
  return (n <= 1 ? n * 100 : n).clamp(0, 100).toDouble();
}

String timeAgo(DateTime? t) {
  if (t == null) return 'no data yet';
  final d = DateTime.now().difference(t);
  if (d.isNegative) return 'just now';
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} d ago';
}

String clockTime(DateTime? t) {
  if (t == null) return '--:--';
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String dayLabel(DateTime? t) {
  if (t == null) return '--';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[t.weekday - 1]} ${t.day}';
}

String dateTimeLabel(DateTime? t) {
  if (t == null) return 'unknown time';
  return '${dayLabel(t)} · ${clockTime(t)}';
}

double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

LatLng? parseLatLng(dynamic map) {
  if (map is! Map) return null;
  final lat = numOf(map['lat']);
  final lng = numOf(map['lng']);
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

// ---------------------------------------------------------------------------
// Patient status
// ---------------------------------------------------------------------------

enum PatientStatus { ok, warn, alert, offline }

Color statusColor(PatientStatus s) {
  switch (s) {
    case PatientStatus.ok:
      return Cg.green;
    case PatientStatus.warn:
      return Cg.amber;
    case PatientStatus.alert:
      return Cg.red;
    case PatientStatus.offline:
      return Cg.muted;
  }
}

String statusLabel(PatientStatus s) {
  switch (s) {
    case PatientStatus.ok:
      return 'All quiet';
    case PatientStatus.warn:
      return 'Check in';
    case PatientStatus.alert:
      return 'Needs attention';
    case PatientStatus.offline:
      return 'No data yet';
  }
}

/// Green = fine, amber = stale location or low battery, red = open alert.
PatientStatus statusFor(
  Map<String, dynamic> p, {
  bool openAlert = false,
  bool anyData = true,
}) {
  if (openAlert) return PatientStatus.alert;
  final seen = dateField(p, 'lastSeen');
  final battery = intOf(p['battery']);
  if (seen == null) {
    // Nothing has synced yet (fresh link) versus a device that stopped.
    final everSynced = p.containsKey('lastLocation') ||
        p.containsKey('lastActiveAt') ||
        p.containsKey('battery');
    return everSynced ? PatientStatus.warn : PatientStatus.offline;
  }
  final stale = DateTime.now().difference(seen).inMinutes > 30;
  final low = battery != null && battery <= 15;
  return (stale || low) ? PatientStatus.warn : PatientStatus.ok;
}

class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 14});

  final PatientStatus status;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: statusColor(status),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor(status).withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label});

  final PatientStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(status, size: 9),
          const SizedBox(width: 6),
          Text(
            label ?? statusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------

String alertLabel(String? type) {
  switch (type) {
    case 'sos':
      return 'SOS pressed';
    case 'geofence':
      return 'Left the safe zone';
    case 'offline':
      return 'Phone offline';
    case 'lowBattery':
      return 'Battery is low';
    case 'fall':
      return 'Possible fall';
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
    case 'fall':
      return Icons.personal_injury;
    default:
      return Icons.notifications_active;
  }
}

Color alertColor(String? type) {
  switch (type) {
    case 'sos':
      return Cg.red;
    case 'geofence':
      return Cg.amber;
    case 'lowBattery':
      return Cg.amber;
    case 'offline':
      return Cg.muted;
    default:
      return Cg.blue;
  }
}

String alertMessage(Map<String, dynamic> d) {
  final stored = strOf(d['message']);
  if (stored.isNotEmpty) return stored;
  switch (d['type']) {
    case 'sos':
      return 'The patient pressed the emergency SOS button.';
    case 'geofence':
      return 'The patient moved outside the safe zone.';
    case 'lowBattery':
      return 'The patient phone battery is low.';
    case 'offline':
      return 'The patient phone stopped reporting.';
    default:
      return 'An alert was raised.';
  }
}

/// True when an alert has no acknowledged timestamp yet.
bool isOpenAlert(Map<String, dynamic> d) =>
    d['ackedAt'] == null && d['status'] != 'acked' && d['status'] != 'resolved';

DateTime? alertTime(Map<String, dynamic> d) =>
    toDate(d['time']) ?? toDate(d['createdAt']) ?? toDate(d['timestamp']);

// ---------------------------------------------------------------------------
// Games
// ---------------------------------------------------------------------------

String gameLabel(String? key) {
  switch (key) {
    case 'memory_pairs':
      return 'Memory Pairs';
    case 'shopping_basket':
      return 'Shopping Basket';
    default:
      return strOf(key, 'Game');
  }
}

IconData gameIcon(String? key) {
  switch (key) {
    case 'memory_pairs':
      return Icons.grid_view_rounded;
    case 'shopping_basket':
      return Icons.shopping_basket;
    default:
      return Icons.sports_esports;
  }
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accent = Cg.navy,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Cg.ink,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  final IconData icon;
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Cg.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Cg.ink),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Cg.slate),
            ),
          ],
        ],
      ),
    );
  }
}

void snack(BuildContext c, String msg) => ScaffoldMessenger.of(c)
    .showSnackBar(SnackBar(content: Text(msg)));

String friendlyError(Object e) {
  final text = e.toString();
  if (text.contains('permission-denied') ||
      text.contains('PERMISSION_DENIED') ||
      text.contains('Missing or insufficient permissions')) {
    return 'Firestore blocked this. Publish the updated security rules '
        '(firebase/firestore.rules) and make sure you are still linked to this patient.';
  }
  if (text.contains('failed-precondition') || text.contains('requires an index')) {
    return 'Firestore still needs an index for this query. Open the link in the '
        'debug console once, then pull down to refresh.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'No connection. The app will retry when the phone is back online.';
  }
  return 'Something went wrong. Please try again.';
}

/// Wording rule from the brief: always show this on key screens.
const String disclaimer =
    'Not a medical device. Engagement trends help caregivers notice change '
    'from baseline; nothing here diagnoses or treats.';

// ---------------------------------------------------------------------------
// Profile fields
// ---------------------------------------------------------------------------

class ProfileField {
  const ProfileField(this.key, this.label, {this.hint, this.multiline = false});

  final String key;
  final String label;
  final String? hint;
  final bool multiline;
}

/// The profile fields a caregiver may edit (mirrored in firestore.rules).
const List<ProfileField> caregiverEditableProfileFields = [
  ProfileField('preferredName', 'Preferred name',
      hint: 'The name the patient likes to be called'),
  ProfileField('age', 'Age'),
  ProfileField('bloodGroup', 'Blood group'),
  ProfileField('languages', 'Languages'),
  ProfileField('homeAddress', 'Home address', multiline: true),
  ProfileField('diagnosis', 'Support needs / condition', multiline: true),
  ProfileField('allergies', 'Allergies', multiline: true),
  ProfileField('medications', 'Daily medications', multiline: true),
  ProfileField('doctorName', 'Doctor name'),
  ProfileField('doctorPhone', 'Doctor phone'),
  ProfileField('caregiverName', 'Primary caregiver name'),
  ProfileField('caregiverRelation', 'Caregiver relationship'),
  ProfileField('caregiverPhone', 'Caregiver phone'),
  ProfileField('comfortPreferences', 'What helps them feel calm', multiline: true),
];
