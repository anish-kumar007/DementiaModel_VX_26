// lib/caregiver/location/location_log_screen.dart
//
// 2) Location log — live position plus the recent location history the patient
// app uploads to patients/{pid}/locationLogs.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';
import '../map/live_map_screen.dart';

class LocationView extends StatelessWidget {
  const LocationView({super.key, required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.patient(pid),
      builder: (context, snap) {
        final patient = snap.data?.data() ?? <String, dynamic>{};
        final location = PatientLocation.fromPatient(patient);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LiveMapCard(
              pid: pid,
              onExpand: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LiveMapScreen(pid: pid)),
              ),
            ),
            const SizedBox(height: 12),
            InfoCard(
              title: 'Sharing status',
              icon: Icons.my_location,
              accent: location.sharingEnabled ? Cg.green : Cg.muted,
              trailing: StatusPill(
                status: location.sharingEnabled
                    ? PatientStatus.ok
                    : PatientStatus.offline,
                label: location.sharingEnabled ? 'Sharing on' : 'Paused',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(
                    icon: Icons.schedule,
                    label: 'Last fix',
                    value: dateTimeLabel(location.seen),
                  ),
                  if (location.accuracy != null)
                    _Row(
                      icon: Icons.gps_fixed,
                      label: 'GPS accuracy',
                      value: '±${location.accuracy!.round()} m',
                    ),
                  if (location.battery != null)
                    _Row(
                      icon: Icons.battery_std,
                      label: 'Battery',
                      value: '${location.battery}%',
                    ),
                  _Row(
                    icon: Icons.shield_outlined,
                    label: 'Safe zone',
                    value: location.radiusM == null
                        ? 'Not set yet'
                        : '${location.radiusM!.round()} m radius'
                            '${location.distanceFromZone == null ? '' : ' · ${location.distanceFromZone!.round()} m away'}',
                  ),
                  if (location.hasPoint) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => openInMaps(
                        location.point!.latitude,
                        location.point!.longitude,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open last position in Maps'),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Location stops when the patient pauses sharing or '
                        'closes the app.',
                        style: TextStyle(fontSize: 12, color: Cg.muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Location history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Cg.ink,
              ),
            ),
            const SizedBox(height: 8),
            LocationLogList(pid: pid, shrinkWrap: true),
          ],
        );
      },
    );
  }
}

class LocationLogList extends StatelessWidget {
  const LocationLogList({
    super.key,
    required this.pid,
    this.shrinkWrap = false,
  });

  final String pid;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.locationLogs(pid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(friendlyError(snap.error!), style: const TextStyle(color: Cg.red));
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.route_outlined,
            message: 'No location history yet',
            hint: 'Readings are added a few times an hour while the patient '
                'app is open.',
          );
        }
        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, index) => _LogTile(doc: docs[index]),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final lat = numOf(d['lat']);
    final lng = numOf(d['lng']);
    final accuracy = numOf(d['accuracy']);
    final battery = intOf(d['battery']);
    final when = toDate(d['time']);
    final source = strOf(d['source'], 'auto');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Cg.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              source == 'sos'
                  ? Icons.sos
                  : (source == 'geofence' ? Icons.wrong_location : Icons.place),
              size: 18,
              color: source == 'auto' ? Cg.navy : Cg.red,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lat == null || lng == null
                      ? 'Unknown position'
                      : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Cg.ink,
                  ),
                ),
                Text(
                  [
                    dateTimeLabel(when),
                    if (accuracy != null) '±${accuracy.round()} m',
                    if (battery != null) '$battery%',
                    if (source != 'auto') source.toUpperCase(),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: Cg.slate),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in Maps',
            onPressed: lat == null || lng == null
                ? null
                : () => openInMaps(lat, lng),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Cg.muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Cg.slate)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Cg.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
