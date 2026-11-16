// lib/caregiver/activity/session_log_screen.dart
//
// 1) Session activity log  — every game session the patient recorded.
// 3) Game scores log       — the same sessions grouped per game, with points.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';

/// Switches between the session log and the score log.
class ActivityView extends StatefulWidget {
  const ActivityView({super.key, required this.pid});

  final String pid;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  String _mode = 'sessions';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'sessions',
                label: Text('Session log'),
                icon: Icon(Icons.list_alt, size: 18),
              ),
              ButtonSegment(
                value: 'scores',
                label: Text('Game scores'),
                icon: Icon(Icons.emoji_events_outlined, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
        ),
        Expanded(
          child: _mode == 'sessions'
              ? SessionLogView(pid: widget.pid)
              : GameScoresView(pid: widget.pid),
        ),
      ],
    );
  }
}

class SessionLogView extends StatefulWidget {
  const SessionLogView({super.key, required this.pid});

  final String pid;

  @override
  State<SessionLogView> createState() => _SessionLogViewState();
}

class _SessionLogViewState extends State<SessionLogView> {
  String _game = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.sessions(widget.pid),
      builder: (context, snap) {
        if (snap.hasError) {
          return _Centered(message: friendlyError(snap.error!));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data!.docs;
        final docs = _game == 'all'
            ? all
            : all.where((d) => d.data()['game'] == _game).toList();

        final week = all.where((d) {
          final t = toDate(d.data()['timestamp']);
          return t != null &&
              t.isAfter(DateTime.now().subtract(const Duration(days: 7)));
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryStrip(
              sessions: all.length,
              weekSessions: week.length,
              weekAccuracy: _average(week.map((d) => d.data())),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'all': 'All games',
                  'memory_pairs': 'Memory Pairs',
                  'shopping_basket': 'Shopping Basket',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                    selected: _game == entry.key,
                    onSelected: (_) => setState(() => _game = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const EmptyState(
                icon: Icons.sports_esports_outlined,
                message: 'No sessions yet',
                hint: 'Sessions appear here as soon as the patient finishes a '
                    'game round. They are queued offline too.',
              )
            else
              for (final doc in docs) _SessionTile(doc: doc),
          ],
        );
      },
    );
  }

  static double _average(Iterable<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;
    final total =
        sessions.fold<double>(0, (sum, s) => sum + accuracyPct(s['accuracy']));
    return total / sessions.length;
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.sessions,
    required this.weekSessions,
    required this.weekAccuracy,
  });

  final int sessions;
  final int weekSessions;
  final double weekAccuracy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Sessions',
            value: '$sessions',
            caption: 'all time',
            color: Cg.navy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: 'This week',
            value: '$weekSessions',
            caption: 'sessions',
            color: Cg.teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: 'Accuracy',
            value: '${weekAccuracy.round()}%',
            caption: 'this week',
            color: Cg.green,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Cg.slate),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            caption,
            style: const TextStyle(fontSize: 11, color: Cg.muted),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final pct = accuracyPct(d['accuracy']);
    final color = pct >= 70 ? Cg.green : (pct >= 40 ? Cg.amber : Cg.red);
    final speed = numOf(d['avgResponseMs']);
    final points = intOf(d['score']);
    final when = toDate(d['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(gameIcon(d['game'] as String?), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gameLabel(d['game'] as String?)} · Level ${intOf(d['level']) ?? '?'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Cg.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${pct.round()}% accuracy'
                  '${speed == null ? '' : ' · ${(speed / 1000).toStringAsFixed(1)} s average answer'}'
                  '${points == null ? '' : ' · $points points'}'
                  '${d['language'] == 'hi' ? ' · Hindi' : ' · English'}',
                  style: const TextStyle(fontSize: 12, color: Cg.slate),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeAgo(when),
                style: const TextStyle(fontSize: 11, color: Cg.muted),
              ),
              if (when != null)
                Text(
                  clockTime(when),
                  style: const TextStyle(fontSize: 11, color: Cg.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Groups sessions per game so a caregiver can see whether scores hold up.
class GameScoresView extends StatelessWidget {
  const GameScoresView({super.key, required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.sessions(pid),
      builder: (context, snap) {
        if (snap.hasError) return _Centered(message: friendlyError(snap.error!));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              EmptyState(
                icon: Icons.emoji_events_outlined,
                message: 'No scores yet',
                hint: 'Play a round on the patient phone and scores land here.',
              ),
            ],
          );
        }

        final groups = <String, List<Map<String, dynamic>>>{};
        for (final doc in docs) {
          final data = doc.data();
          final key = strOf(data['game'], 'game');
          groups.putIfAbsent(key, () => []).add(data);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in groups.entries)
              _GameCard(gameKey: entry.key, sessions: entry.value),
            const SizedBox(height: 4),
            Text(
              'Scores compare the patient with their own earlier rounds only. '
              'Accuracy is the share of correct answers in a session.',
              style: TextStyle(fontSize: 11, color: Cg.muted.withValues(alpha: 1)),
            ),
          ],
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.gameKey, required this.sessions});

  final String gameKey;
  final List<Map<String, dynamic>> sessions;

  @override
  Widget build(BuildContext context) {
    final accuracies = sessions.map((s) => accuracyPct(s['accuracy'])).toList();
    final avg = accuracies.reduce((a, b) => a + b) / accuracies.length;
    final best = accuracies.reduce((a, b) => a > b ? a : b);
    final points = sessions
        .map((s) => intOf(s['score']))
        .whereType<int>()
        .toList();
    final speeds = sessions
        .map((s) => numOf(s['avgResponseMs']))
        .whereType<double>()
        .toList();
    final latest = sessions.isEmpty ? null : toDate(sessions.first['timestamp']);

    double? avgSpeed;
    if (speeds.isNotEmpty) {
      avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length / 1000;
    }

    return InfoCard(
      title: gameLabel(gameKey),
      icon: gameIcon(gameKey),
      accent: Cg.teal,
      trailing: StatusPill(
        status: avg >= 70
            ? PatientStatus.ok
            : (avg >= 40 ? PatientStatus.warn : PatientStatus.alert),
        label: '${avg.round()}% avg',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Stat(label: 'Rounds', value: '${sessions.length}'),
              _Stat(label: 'Best accuracy', value: '${best.round()}%'),
              if (avgSpeed != null)
                _Stat(label: 'Avg answer', value: '${avgSpeed.toStringAsFixed(1)} s'),
              if (points.isNotEmpty)
                _Stat(
                  label: 'Best points',
                  value: '${points.reduce((a, b) => a > b ? a : b)}',
                ),
              _Stat(label: 'Last played', value: timeAgo(latest)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Cg.cardBorder),
          const SizedBox(height: 8),
          for (final s in sessions.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      timeAgo(toDate(s['timestamp'])),
                      style: const TextStyle(fontSize: 12, color: Cg.muted),
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      'L${intOf(s['level']) ?? '?'}',
                      style: const TextStyle(fontSize: 12, color: Cg.slate),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${accuracyPct(s['accuracy']).round()}% accuracy',
                      style: const TextStyle(fontSize: 12, color: Cg.ink),
                    ),
                  ),
                  if (intOf(s['score']) != null)
                    Text(
                      '${intOf(s['score'])} pts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Cg.teal,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Cg.muted)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Cg.ink,
          ),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
