// lib/caregiver/alerts/alerts_screen.dart
//
// 8) Alert log: every alert the patient app raised (SOS, safe zone, battery,
// offline), newest first, with acknowledge.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';
import '../map/live_map_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.pid, this.highlightId});

  final String pid;
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('Alerts'),
      ),
      body: AlertsView(pid: pid, highlightId: highlightId),
    );
  }
}

class AlertsView extends StatefulWidget {
  const AlertsView({super.key, required this.pid, this.highlightId});

  final String pid;
  final String? highlightId;

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  bool _onlyOpen = false;

  Future<void> _ack(String alertId) async {
    try {
      await CaregiverRepo.ackAlert(widget.pid, alertId);
      if (!mounted) return;
      snack(context, 'Alert acknowledged.');
    } catch (e) {
      if (!mounted) return;
      snack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.alerts(widget.pid),
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

        final all = snap.data!.docs;
        final open = all.where((d) => isOpenAlert(d.data())).toList();
        final visible = _onlyOpen ? open : all;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      open.isEmpty
                          ? 'All alerts acknowledged'
                          : '${open.length} open alert${open.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: open.isEmpty ? Cg.green : Cg.red,
                      ),
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('All')),
                      ButtonSegment(value: true, label: Text('Open')),
                    ],
                    selected: {_onlyOpen},
                    onSelectionChanged: (value) =>
                        setState(() => _onlyOpen = value.first),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        EmptyState(
                          icon: Icons.verified_user,
                          message: _onlyOpen
                              ? 'Nothing open right now'
                              : 'No alerts yet',
                          hint: _onlyOpen
                              ? 'Every recorded alert has been acknowledged.'
                              : 'SOS and safe-zone alerts from the patient app '
                                  'appear here.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final doc = visible[index];
                        return _AlertCard(
                          pid: widget.pid,
                          doc: doc,
                          highlight: doc.id == widget.highlightId,
                          onAck: () => _ack(doc.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.pid,
    required this.doc,
    required this.highlight,
    required this.onAck,
  });

  final String pid;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool highlight;
  final VoidCallback onAck;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final type = d['type'] as String?;
    final open = isOpenAlert(d);
    final color = open ? alertColor(type) : Cg.muted;
    final location = parseLatLng(d['location']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? alertColor(type) : Cg.cardBorder,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(alertIcon(type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alertLabel(type),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Cg.ink,
                        ),
                      ),
                      Text(
                        dateTimeLabel(alertTime(d)),
                        style: const TextStyle(fontSize: 12, color: Cg.slate),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  status: open ? PatientStatus.alert : PatientStatus.ok,
                  label: open ? 'OPEN' : 'Acknowledged',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              alertMessage(d),
              style: const TextStyle(fontSize: 13, color: Cg.slate, height: 1.35),
            ),
            if (numOf(d['distanceMeters']) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${numOf(d['distanceMeters'])!.round()} m from the safe zone '
                  'centre (limit ${numOf(d['radiusMeters'])?.round() ?? '?'} m).',
                  style: const TextStyle(fontSize: 12, color: Cg.muted),
                ),
              ),
            if (!open && d['ackedBy'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Acknowledged ${timeAgo(toDate(d['ackedAt']))}',
                  style: const TextStyle(fontSize: 12, color: Cg.green),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (open)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Cg.navy,
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onAck,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Acknowledge'),
                    ),
                  ),
                if (location != null) ...[
                  if (open) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () {
                        // Inside the dashboard, the Location tab is the one
                        // place with the map and its history.
                        final tabs = DefaultTabController.maybeOf(context);
                        if (tabs != null) {
                          tabs.animateTo(2);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveMapScreen(pid: pid),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Map'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
