// lib/services/reminder_utils.dart
//
// Reminders are written by the caregiver as patients/{pid}/reminders/{id}:
//   {title, type: medication|hydration|game, time: "HH:mm", repeat: daily|once,
//    active: bool, lastDoneOn: "yyyy-MM-dd"?, lastDoneAt: Timestamp?}
// The patient app reads and ticks them, so both sides parse time in one place.

class ReminderTime {
  /// Accepts "HH:mm", "H:mm" and legacy "09:00 AM" strings.
  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(value);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;

    final meridiem = match.group(3);
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static String to24h(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static String to12h(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) return raw ?? '--:--';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')} '
        '${parsed.hour < 12 ? 'AM' : 'PM'}';
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool isDoneToday(Map<String, dynamic> reminder) {
    return reminder['lastDoneOn'] == dateKey(DateTime.now());
  }

  /// The next active reminder after [now], looked at today and tomorrow.
  static Map<String, dynamic>? next(
    List<Map<String, dynamic>> reminders, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    Map<String, dynamic>? best;
    DateTime? bestAt;

    for (final r in reminders) {
      if (r['active'] == false) continue;
      final at = parse(r['time'] as String?);
      if (at == null) continue;
      var candidate = at;
      if (candidate.isBefore(current)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (bestAt == null || candidate.isBefore(bestAt)) {
        bestAt = candidate;
        best = r;
      }
    }
    return best;
  }
}

/// Sort helper: reminders by their clock time, unknown times last.
int compareReminderTime(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ta = ReminderTime.parse(a['time'] as String?);
  final tb = ReminderTime.parse(b['time'] as String?);
  if (ta == null && tb == null) return 0;
  if (ta == null) return 1;
  if (tb == null) return -1;
  return ta.compareTo(tb);
}
