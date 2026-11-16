// lib/caregiver/assistant/care_insights.dart
//
// The caregiver care assistant. It answers in plain language using only the
// records already in Firestore (sessions, alerts, location, reminders,
// contacts, assistant chats). No model call, no network, no medical advice:
// every answer is a summary of stored facts, which is what a caregiver needs
// in a hurry and what keeps the demo reliable offline.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/reminder_utils.dart';
import '../common.dart';

class CareContext {
  const CareContext({
    required this.patient,
    this.sessions = const [],
    this.alerts = const [],
    this.locations = const [],
    this.reminders = const [],
    this.contacts = const [],
    this.chats = const [],
  });

  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> chats;

  String get name => strOf(patient['name'], 'your patient');
  String get preferred =>
      strOf(patient['preferredName'], strOf(patient['name'], 'the patient'));

  /// Builds a context from the maps the screens already hold.
  static CareContext fromDocs({
    required Map<String, dynamic> patient,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sessions,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> alerts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> locations,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> reminders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> contacts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> chats = const [],
  }) {
    return CareContext(
      patient: patient,
      sessions: [for (final d in sessions) d.data()],
      alerts: [for (final d in alerts) d.data()],
      locations: [for (final d in locations) d.data()],
      reminders: [for (final d in reminders) d.data()],
      contacts: [for (final d in contacts) d.data()],
      chats: [for (final d in chats) d.data()],
    );
  }
}

class CareInsights {
  static const List<String> quickQuestions = [
    'Give me today\'s briefing',
    'Where is my patient now?',
    'How did the games go this week?',
    'Are there any open alerts?',
    'What reminders are set?',
    'Has anything changed from baseline?',
    'What is in the profile?',
  ];

  static String answer(String question, CareContext ctx) {
    final q = question.toLowerCase();

    if (_has(q, ['brief', 'summary', 'overview', 'how is', 'everything'])) {
      return briefing(ctx);
    }
    if (_has(q, ['where', 'location', 'gps', 'map', 'outside', 'lost', 'safe'])) {
      return _location(ctx);
    }
    if (_has(q, ['game', 'play', 'session', 'accuracy', 'memory', 'score', 'activity'])) {
      return _games(ctx);
    }
    if (_has(q, ['alert', 'sos', 'emergency', 'danger', 'warn'])) {
      return _alerts(ctx);
    }
    if (_has(q, ['remind', 'medicine', 'medication', 'tablet', 'water', 'routine', 'dose'])) {
      return _reminders(ctx);
    }
    if (_has(q, ['contact', 'doctor', 'phone', 'call', 'family'])) {
      return _contacts(ctx);
    }
    if (_has(q, ['trend', 'change', 'baseline', 'better', 'worse', 'improve', 'compare'])) {
      return _trend(ctx);
    }
    if (_has(q, ['profile', 'allerg', 'address', 'blood', 'condition', 'who is'])) {
      return _profile(ctx);
    }
    if (_has(q, ['asked', 'assistant', 'voice', 'said'])) {
      return _conversations(ctx);
    }
    if (_has(q, ['help', 'what can you', 'hello', 'hi ', 'namaste'])) {
      return 'I can summarise this patient\'s recorded care: location and '
          'last check-in, game activity and scores, alerts, reminders, '
          'contacts, profile details and changes from baseline. '
          'Ask me something like “give me today\'s briefing”.';
    }

    return '${briefing(ctx)}\n\nI did not match that question to a record. '
        'Try asking about location, games, alerts, reminders, contacts or '
        'trends.';
  }

  static String briefing(CareContext ctx) {
    final lines = <String>[];

    // Safety first.
    final open = ctx.alerts.where(isOpenAlert).toList();
    if (open.isEmpty) {
      lines.add('Safety: no open alerts in the recent log.');
    } else {
      final latest = open.first;
      lines.add(
        'Safety: ${open.length} open alert${open.length == 1 ? '' : 's'} — '
        'latest is “${alertLabel(latest['type'] as String?)}” '
        '${timeAgo(alertTime(latest))}.',
      );
    }

    // Connection.
    final seen = dateField(ctx.patient, 'lastSeen');
    final battery = intOf(ctx.patient['battery']);
    lines.add(
      'Device: last check-in ${timeAgo(seen)}'
      '${battery == null ? '' : ' · battery $battery%'}.',
    );

    // Games today.
    final today = _sessionsSince(ctx, DateTime.now().subtract(const Duration(days: 1)));
    if (today.isEmpty) {
      lines.add('Games: no session recorded in the last 24 hours.');
    } else {
      final avg = _avgAccuracy(today);
      final names = today.map((s) => gameLabel(s['game'] as String?)).toSet();
      lines.add(
        'Games: ${today.length} session${today.length == 1 ? '' : 's'} in the '
        'last day (${names.join(', ')}), average accuracy '
        '${avg.round()}%.',
      );
    }

    // Routine.
    final next = ReminderTime.next(ctx.reminders);
    if (next != null) {
      lines.add(
        'Routine: next reminder ${ReminderTime.to12h(next['time'] as String?)} '
        '— ${strOf(next['title'], 'reminder')}.',
      );
    } else if (ctx.reminders.isEmpty) {
      lines.add('Routine: no reminders set yet.');
    } else {
      lines.add('Routine: all reminders for today have passed.');
    }

    // Where.
    final last = _latestLocation(ctx);
    if (last != null) {
      lines.add('Location: last fix ${timeAgo(dateField(last, 'time'))}'
          '${_zoneNote(ctx, last)}.');
    } else {
      lines.add('Location: no location fix recorded yet.');
    }

    return 'Here is ${ctx.name}\'s briefing.\n\n${lines.join('\n')}';
  }

  // -------------------------------------------------------------------------

  static String _location(CareContext ctx) {
    final last = _latestLocation(ctx);
    final zone = ctx.patient['safeZone'] as Map<String, dynamic>?;
    if (last == null) {
      return 'No location has been recorded yet. Location is shared while the '
          'patient app is open and sharing consent is on.';
    }

    final lat = numOf(last['lat']);
    final lng = numOf(last['lng']);
    final accuracy = numOf(last['accuracy']);
    final when = dateField(last, 'time');

    final parts = <String>[
      'Last location: ${lat?.toStringAsFixed(5)}, ${lng?.toStringAsFixed(5)} '
          '(${timeAgo(when)}).',
      if (accuracy != null) 'GPS accuracy about ${accuracy.round()} m.',
      if (zone != null) _zoneNote(ctx, last).replaceFirst(' · ', ''),
    ]..removeWhere((part) => part.trim().isEmpty);

    final battery = intOf(ctx.patient['battery']);
    if (battery != null) {
      parts.add('Battery is $battery%.');
    }
    if (ctx.patient['locationSharingEnabled'] == false) {
      parts.add('Location sharing is currently paused by the patient.');
    }
    return parts.join('\n');
  }

  static String _zoneNote(CareContext ctx, Map<String, dynamic> location) {
    final zone = ctx.patient['safeZone'] as Map<String, dynamic>?;
    if (zone == null) return ' · no safe zone set';
    final lat = numOf(location['lat']);
    final lng = numOf(location['lng']);
    final zLat = numOf(zone['lat']);
    final zLng = numOf(zone['lng']);
    final radius = numOf(zone['radiusM']);
    if (lat == null || lng == null || zLat == null || zLng == null || radius == null) {
      return '';
    }
    final distance = metersBetween(lat, lng, zLat, zLng);
    final inside = distance <= radius;
    return ' · ${inside ? 'inside' : 'outside'} the safe zone '
        '(${distance.round()} m from centre, limit ${radius.round()} m)';
  }

  static String _games(CareContext ctx) {
    if (ctx.sessions.isEmpty) {
      return 'No game sessions yet. Sessions are saved when the patient '
          'finishes a round of Memory Pairs or Shopping Basket.';
    }

    final week = _sessionsSince(ctx, DateTime.now().subtract(const Duration(days: 7)));
    final today = _sessionsSince(ctx, DateTime.now().subtract(const Duration(days: 1)));
    final weekAvg = _avgAccuracy(week);
    final weekSpeed = _avgSpeed(week);

    final byGame = <String, List<Map<String, dynamic>>>{};
    for (final s in week) {
      byGame.putIfAbsent(gameLabel(s['game'] as String?), () => []).add(s);
    }

    final lines = <String>[
      'Games in the last 7 days: ${week.length} session${week.length == 1 ? '' : 's'}.',
      if (today.isNotEmpty)
        'In the last day: ${today.length} session${today.length == 1 ? '' : 's'}, '
            'average accuracy ${_avgAccuracy(today).round()}%.',
      if (week.isNotEmpty)
        'Weekly average accuracy ${weekAvg.round()}%'
            '${weekSpeed == null ? '' : ' · average answer time ${weekSpeed.toStringAsFixed(1)} s'}.',
      for (final entry in byGame.entries)
        '${entry.key}: ${entry.value.length} played, best accuracy '
            '${_avgAccuracy(entry.value).round()}% average.',
    ];

    final scored = week.where((s) => intOf(s['score']) != null).toList();
    if (scored.isNotEmpty) {
      final best = scored
          .map((s) => intOf(s['score'])!)
          .reduce((a, b) => a > b ? a : b);
      lines.add('Best recorded points this week: $best.');
    }

    return lines.join('\n');
  }

  static String _alerts(CareContext ctx) {
    final open = ctx.alerts.where(isOpenAlert).toList();
    if (ctx.alerts.isEmpty) {
      return 'No alerts have been recorded for this patient yet.';
    }
    if (open.isEmpty) {
      return 'No open alerts. The most recent alert was '
          '“${alertLabel(ctx.alerts.first['type'] as String?)}”, '
          '${timeAgo(alertTime(ctx.alerts.first))}, and it is acknowledged.';
    }
    final lines = <String>[
      '${open.length} open alert${open.length == 1 ? '' : 's'}:',
      for (final a in open.take(5))
        '• ${alertLabel(a['type'] as String?)} — ${timeAgo(alertTime(a))}',
      'Open the Alerts tab to acknowledge them.',
    ];
    return lines.join('\n');
  }

  static String _reminders(CareContext ctx) {
    if (ctx.reminders.isEmpty) {
      return 'No reminders are set. Add them from More → Reminders so they '
          'appear on the patient phone.';
    }
    final next = ReminderTime.next(ctx.reminders);
    final lines = <String>[
      '${ctx.reminders.length} reminder${ctx.reminders.length == 1 ? '' : 's'} set'
          ' (${ctx.reminders.where((r) => r['active'] != false).length} active).',
      if (next != null)
        'Next: ${ReminderTime.to12h(next['time'] as String?)} — '
            '${strOf(next['title'], 'reminder')}.',
      for (final r in ctx.reminders.take(5))
        '• ${ReminderTime.to12h(r['time'] as String?)} — '
            '${strOf(r['title'], 'reminder')}'
            '${ReminderTime.isDoneToday(r) ? ' (done today)' : ''}',
    ];
    return lines.join('\n');
  }

  static String _contacts(CareContext ctx) {
    if (ctx.contacts.isEmpty) {
      final doctor = strOf(ctx.patient['doctorName']);
      final phone = strOf(ctx.patient['doctorPhone']);
      if (doctor.isNotEmpty) {
        return 'No contacts added. The profile lists doctor $doctor'
            '${phone.isEmpty ? '' : ' ($phone)'}.';
      }
      return 'No contacts are set. Add them from More → Contacts so the '
          'patient can call with one tap.';
    }
    final lines = <String>[
      'Contacts the patient can call:',
      for (final c in ctx.contacts.take(6))
        '• ${strOf(c['name'], 'Contact')}'
            '${strOf(c['relation']).isEmpty ? '' : ' (${strOf(c['relation'])})'}'
            '${c['isDoctor'] == true ? ' · doctor' : ''}'
            ' — ${strOf(c['phone'], 'no number')}',
    ];
    return lines.join('\n');
  }

  static String _trend(CareContext ctx) {
    final now = DateTime.now();
    final recent = _sessionsSince(ctx, now.subtract(const Duration(days: 7)));
    final previous = _sessionsBetween(
      ctx,
      now.subtract(const Duration(days: 14)),
      now.subtract(const Duration(days: 7)),
    );

    if (recent.isEmpty && previous.isEmpty) {
      return 'There is not enough game data yet to compare with a baseline. '
          'A few sessions usually arrive after the patient plays.';
    }
    if (previous.isEmpty) {
      return 'This is the first week of data (${recent.length} sessions, average '
          'accuracy ${_avgAccuracy(recent).round()}%). A change from baseline '
          'appears once there is an earlier week to compare with.';
    }
    if (recent.isEmpty) {
      return 'No sessions in the last 7 days, against ${previous.length} the week '
          'before. That drop in engagement is worth a gentle check-in.';
    }

    final recentAvg = _avgAccuracy(recent);
    final previousAvg = _avgAccuracy(previous);
    final delta = recentAvg - previousAvg;
    final direction = delta >= 0 ? 'higher' : 'lower';

    return 'Engagement this week: ${recent.length} sessions at '
        '${recentAvg.round()}% average accuracy, against '
        '${previous.length} sessions at ${previousAvg.round()}% last week. '
        'That is ${delta.abs().round()} points $direction than the earlier week.'
        '\nThis compares the patient with their own earlier sessions, not with '
        'anyone else.';
  }

  static String _profile(CareContext ctx) {
    final p = ctx.patient;
    String first(String key, [String fallback = 'not set']) => strOf(p[key], fallback);

    return 'Profile for ${first('name', 'this patient')}:\n'
        '• Preferred name: ${first('preferredName')}\n'
        '• Age: ${first('age')} · Blood group: ${first('bloodGroup')}\n'
        '• Languages: ${first('languages')}\n'
        '• Home: ${first('homeAddress')}\n'
        '• Support needs: ${first('diagnosis')}\n'
        '• Allergies: ${first('allergies')}\n'
        '• Daily medications: ${first('medications')}\n'
        '• Doctor: ${first('doctorName')} ${first('doctorPhone', '')}\n'
        '• Primary caregiver: ${first('caregiverName')} '
        '(${first('caregiverRelation', 'relationship not set')})\n'
        '• Calming preferences: ${first('comfortPreferences')}';
  }

  static String _conversations(CareContext ctx) {
    if (ctx.chats.isEmpty) {
      return 'The patient has not used the voice assistant yet, or those turns '
          'have not synced.';
    }
    final lines = <String>[
      'Recent assistant conversations:',
      for (final c in ctx.chats.take(5))
        '• “${strOf(c['question'], 'no question')}” → '
            '“${strOf(c['reply'], 'no reply')}” (${timeAgo(dateField(c, 'time'))})',
    ];
    return lines.join('\n');
  }

  // -------------------------------------------------------------------------

  static bool _has(String q, List<String> keys) =>
      keys.any((k) => q.contains(k));

  static Map<String, dynamic>? _latestLocation(CareContext ctx) {
    Map<String, dynamic>? best = ctx.patient['lastLocation'] as Map<String, dynamic>?;
    for (final l in ctx.locations) {
      final t = dateField(l, 'time');
      final bestT = best == null ? null : dateField(best, 'time');
      if (t != null && (bestT == null || t.isAfter(bestT))) {
        best = l;
      }
    }
    return best;
  }

  static List<Map<String, dynamic>> _sessionsSince(CareContext ctx, DateTime from) {
    return ctx.sessions.where((s) {
      final t = toDate(s['timestamp']);
      return t != null && t.isAfter(from);
    }).toList();
  }

  static List<Map<String, dynamic>> _sessionsBetween(
    CareContext ctx,
    DateTime from,
    DateTime to,
  ) {
    return ctx.sessions.where((s) {
      final t = toDate(s['timestamp']);
      return t != null && t.isAfter(from) && t.isBefore(to);
    }).toList();
  }

  static double _avgAccuracy(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;
    final total = sessions.fold<double>(
      0,
      (sum, s) => sum + accuracyPct(s['accuracy']),
    );
    return total / sessions.length;
  }

  static double? _avgSpeed(List<Map<String, dynamic>> sessions) {
    final withMs =
        sessions.where((s) => numOf(s['avgResponseMs']) != null).toList();
    if (withMs.isEmpty) return null;
    final total = withMs.fold<double>(
      0,
      (sum, s) => sum + numOf(s['avgResponseMs'])!,
    );
    return total / withMs.length / 1000;
  }
}
