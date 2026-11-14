// app/lib/caregiver/trends/trends_screen.dart
// Reads patients/{pid}/daily/{yyyy-MM-dd}: avgAccuracy, avgResponseMs,
// sessionsCount, baselineFlag, insight. Wording: "change from baseline",
// "engagement trends". Never "diagnosis".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key, required this.pid});
  final String pid;

  @override
  Widget build(BuildContext context) {
    // Doc ids are dates, so ordering by id gives the last 30 days.
    final stream = patientRef(pid)
        .collection('daily')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(30)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Engagement trends')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load trends.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = snap.data!.docs.reversed.toList(); // oldest first
          if (days.length < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Not enough days yet. Trends appear after a few days of games.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final acc = <FlSpot>[];
          final speed = <FlSpot>[];
          final flagged = <int>{};
          String? insight;
          for (var i = 0; i < days.length; i++) {
            final d = days[i].data();
            double a = (d['avgAccuracy'] as num?)?.toDouble() ?? 0;
            if (a <= 1) a *= 100; // accept 0-1 or 0-100
            acc.add(FlSpot(i.toDouble(), a));
            final ms = (d['avgResponseMs'] as num?)?.toDouble() ?? 0;
            speed.add(FlSpot(i.toDouble(), ms / 1000)); // seconds
            if (d['baselineFlag'] == true) flagged.add(i);
            if (d['insight'] is String && (d['insight'] as String).isNotEmpty) {
              insight = d['insight'] as String; // latest one wins
            }
          }

          String dayLabel(int i) {
            final id = days[i.clamp(0, days.length - 1)].id; // yyyy-MM-dd
            return id.length >= 10 ? id.substring(8, 10) : id;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InfoCard(
                title: 'Insight',
                child: Text(
                  insight ?? 'No change from baseline noted.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              _Chart(
                title: 'Accuracy (%)',
                spots: acc,
                flagged: flagged,
                minY: 0,
                maxY: 100,
                dayLabel: dayLabel,
              ),
              _Chart(
                title: 'Response time (seconds)',
                spots: speed,
                flagged: flagged,
                minY: 0,
                maxY: null,
                dayLabel: dayLabel,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(Icons.circle, size: 12, color: Color(0xFFC62828)),
                  SizedBox(width: 6),
                  Text('Day with change from baseline'),
                ]),
              ),
              Text(disclaimer, style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.title,
    required this.spots,
    required this.flagged,
    required this.minY,
    required this.maxY,
    required this.dayLabel,
  });
  final String title;
  final List<FlSpot> spots;
  final Set<int> flagged;
  final double minY;
  final double? maxY;
  final String Function(int) dayLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InfoCard(
      title: title,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(dayLabel(v.toInt()),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: color,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  // Flagged days get a bigger red dot.
                  getDotPainter: (spot, percent, bar, index) {
                    final isFlag = flagged.contains(spot.x.toInt());
                    return FlDotCirclePainter(
                      radius: isFlag ? 6 : 2.5,
                      color: isFlag ? const Color(0xFFC62828) : color,
                      strokeWidth: 0,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}