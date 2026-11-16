// lib/caregiver/trends/trends_screen.dart
//
// Engagement trends computed from patients/{pid}/sessions, so they work as soon
// as the patient plays. Wording: "change from baseline", "engagement trends".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';

class _DayPoint {
  _DayPoint(this.day, this.sessions, this.accuracy, this.speedSeconds);

  final DateTime day;
  final int sessions;
  final double accuracy;
  final double speedSeconds;
}

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key, required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('Engagement trends'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CaregiverRepo.sessions(pid, limit: 300),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  friendlyError(snap.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final days = _bucketByDay(snap.data!.docs);
          if (days.length < 2) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                EmptyState(
                  icon: Icons.show_chart,
                  message: 'Not enough days yet',
                  hint: 'Trends appear after the patient has played on two or '
                      'more days. Each point is one day of sessions.',
                ),
              ],
            );
          }

          final accuracySpots = <FlSpot>[
            for (var i = 0; i < days.length; i++)
              FlSpot(i.toDouble(), days[i].accuracy),
          ];
          final speedSpots = <FlSpot>[
            for (var i = 0; i < days.length; i++)
              FlSpot(i.toDouble(), days[i].speedSeconds),
          ];

          final flags = _flagDays(days);
          final insight = _insight(days, flags.values.where((v) => v).length);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InfoCard(
                title: 'Insight',
                icon: Icons.insights,
                accent: Cg.violet,
                child: Text(
                  insight,
                  style: const TextStyle(color: Cg.slate, height: 1.4),
                ),
              ),
              InfoCard(
                title: 'Accuracy (%)',
                icon: Icons.percent,
                accent: Cg.teal,
                child: _Chart(
                  spots: accuracySpots,
                  flagged: flags,
                  days: days,
                  minY: 0,
                  maxY: 100,
                ),
              ),
              InfoCard(
                title: 'Answer time (seconds)',
                icon: Icons.timer_outlined,
                accent: Cg.blue,
                child: _Chart(
                  spots: speedSpots,
                  flagged: flags,
                  days: days,
                  minY: 0,
                  maxY: null,
                ),
              ),
              InfoCard(
                title: 'Sessions per day',
                icon: Icons.bar_chart,
                accent: Cg.amber,
                child: Column(
                  children: [
                    for (final day in days.reversed.take(7))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 62,
                              child: Text(
                                dayLabel(day.day),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Cg.slate,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: (day.sessions / 6).clamp(0.05, 1.0),
                                  backgroundColor: Cg.surface,
                                  color: Cg.amber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${day.sessions} · ${day.accuracy.round()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Cg.slate,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: Cg.red),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Day below this patient\'s own baseline',
                        style: TextStyle(fontSize: 12, color: Cg.slate),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                disclaimer,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Cg.muted),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<_DayPoint> _bucketByDay(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final data = doc.data();
      final at = toDate(data['timestamp']);
      if (at == null) continue;
      final key = '${at.year}-${at.month}-${at.day}';
      buckets.putIfAbsent(key, () => []).add(data);
    }

    final days = <_DayPoint>[];
    buckets.forEach((key, sessions) {
      final parts = key.split('-').map(int.parse).toList();
      final day = DateTime(parts[0], parts[1], parts[2]);
      final accuracy = sessions.fold<double>(
            0,
            (sum, s) => sum + accuracyPct(s['accuracy']),
          ) /
          sessions.length;
      final speeds = sessions
          .map((s) => numOf(s['avgResponseMs']))
          .whereType<double>()
          .toList();
      final speed = speeds.isEmpty
          ? 0.0
          : speeds.reduce((a, b) => a + b) / speeds.length / 1000;
      days.add(_DayPoint(day, sessions.length, accuracy, speed));
    });

    days.sort((a, b) => a.day.compareTo(b.day));
    return days;
  }

  /// Marks days that sit more than one standard deviation below the patient's
  /// own daily average. Only used with three or more days of data.
  static Map<int, bool> _flagDays(List<_DayPoint> days) {
    final flags = <int, bool>{};
    if (days.length < 3) return flags;

    final mean = days.fold<double>(0, (s, d) => s + d.accuracy) / days.length;
    final variance = days.fold<double>(
          0,
          (s, d) => s + (d.accuracy - mean) * (d.accuracy - mean),
        ) /
        days.length;
    final sd = variance <= 0 ? 0.0 : _sqrt(variance);
    final threshold = mean - (sd == 0 ? 12 : sd);

    for (var i = 0; i < days.length; i++) {
      flags[i] = days[i].accuracy < threshold;
    }
    return flags;
  }

  static double _sqrt(double value) {
    var x = value;
    for (var i = 0; i < 20; i++) {
      x = 0.5 * (x + value / x);
    }
    return x;
  }

  static String _insight(List<_DayPoint> days, int flagged) {
    final first = days.first.accuracy;
    final last = days.last.accuracy;
    final delta = last - first;
    final direction = delta >= 0 ? 'higher' : 'lower';

    final text = StringBuffer(
      'Across ${days.length} days of play, accuracy moved from '
      '${first.round()}% to ${last.round()}% — ${delta.abs().round()} points '
      '$direction than the first recorded day. '
      'Total sessions: ${days.fold<int>(0, (s, d) => s + d.sessions)}.',
    );
    if (flagged > 0) {
      text.write(
        ' $flagged day${flagged == 1 ? '' : 's'} sit below the usual range; '
        'a gentle check-in may help.',
      );
    } else {
      text.write(' No day is below the usual range for this patient.');
    }
    return text.toString();
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.spots,
    required this.flagged,
    required this.days,
    required this.minY,
    required this.maxY,
  });

  final List<FlSpot> spots;
  final Map<int, bool> flagged;
  final List<_DayPoint> days;
  final double minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 34),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (days.length / 4).clamp(1, 10).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      dayLabel(days[index].day),
                      style: const TextStyle(fontSize: 10, color: Cg.slate),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Cg.teal,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: Cg.teal.withValues(alpha: 0.08),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final isFlag = flagged[spot.x.toInt()] == true;
                  return FlDotCirclePainter(
                    radius: isFlag ? 6 : 3,
                    color: isFlag ? Cg.red : Cg.teal,
                    strokeWidth: 0,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
