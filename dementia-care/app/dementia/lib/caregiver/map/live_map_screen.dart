// lib/caregiver/map/live_map_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';

Future<void> openInMaps(double lat, double lng) async {
  final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class PatientLocation {
  const PatientLocation({
    required this.point,
    required this.zoneCenter,
    required this.radiusM,
    required this.accuracy,
    required this.seen,
    required this.battery,
    required this.sharingEnabled,
  });

  final LatLng? point;
  final LatLng? zoneCenter;
  final double? radiusM;
  final double? accuracy;
  final DateTime? seen;
  final int? battery;
  final bool sharingEnabled;

  static PatientLocation fromPatient(Map<String, dynamic> p) {
    final last = p['lastLocation'] as Map<String, dynamic>?;
    final zone = p['safeZone'] as Map<String, dynamic>?;
    return PatientLocation(
      point: parseLatLng(last),
      zoneCenter: parseLatLng(zone),
      radiusM: numOf(zone?['radiusM']),
      accuracy: numOf(last?['accuracy']),
      seen: dateField(last, 'time') ?? toDate(p['lastSeen']),
      battery: intOf(p['battery']),
      sharingEnabled: p['locationSharingEnabled'] != false,
    );
  }

  bool get hasPoint => point != null;

  bool? get insideZone {
    if (point == null || zoneCenter == null || radiusM == null) return null;
    return metersBetween(
          point!.latitude,
          point!.longitude,
          zoneCenter!.latitude,
          zoneCenter!.longitude,
        ) <=
        radiusM!;
  }

  double? get distanceFromZone {
    if (point == null || zoneCenter == null) return null;
    return metersBetween(
      point!.latitude,
      point!.longitude,
      zoneCenter!.latitude,
      zoneCenter!.longitude,
    );
  }
}

/// Map card used inside the Location tab.
class LiveMapCard extends StatefulWidget {
  const LiveMapCard({
    super.key,
    required this.pid,
    this.height = 260,
    this.onExpand,
  });

  final String pid;
  final double height;

  /// Shows a "Full map" button when the card can open the larger view.
  final VoidCallback? onExpand;

  @override
  State<LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<LiveMapCard> {
  final MapController _controller = MapController();
  LatLng? _lastMoved;

  static const _fallback = LatLng(28.6139, 77.2090);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.patient(widget.pid),
      builder: (context, snap) {
        if (snap.hasError) {
          return _MapFrame(
            height: widget.height,
            child: Center(child: Text(friendlyError(snap.error!))),
          );
        }
        final patient = snap.data?.data() ?? <String, dynamic>{};
        final location = PatientLocation.fromPatient(patient);
        final centre = location.point ?? location.zoneCenter ?? _fallback;

        if (location.point != null && location.point != _lastMoved) {
          _lastMoved = location.point;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _controller.move(location.point!, 16);
          });
        }

        return _MapFrame(
          height: widget.height,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: centre,
                  initialZoom: 16,
                  minZoom: 4,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.dementia_care',
                  ),
                  if (location.zoneCenter != null && location.radiusM != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: location.zoneCenter!,
                          radius: location.radiusM!,
                          useRadiusInMeter: true,
                          color: const Color(0x332E7D32),
                          borderColor: Cg.green,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (location.zoneCenter != null)
                        Marker(
                          point: location.zoneCenter!,
                          width: 34,
                          height: 34,
                          child: const Icon(
                            Icons.home,
                            size: 26,
                            color: Cg.green,
                          ),
                        ),
                      if (location.point != null)
                        Marker(
                          point: location.point!,
                          width: 46,
                          height: 46,
                          child: Icon(
                            Icons.location_on,
                            size: 44,
                            color: location.insideZone == false ? Cg.red : Cg.navy,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _MapChip(
                  icon: Icons.schedule,
                  label: timeAgo(location.seen),
                  color: Cg.navy,
                ),
              ),
              if (widget.onExpand != null)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: widget.onExpand,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full, size: 15, color: Cg.navy),
                            SizedBox(width: 6),
                            Text(
                              'Full map',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Cg.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (location.insideZone != null)
                Positioned(
                  right: 10,
                  top: 54,
                  child: _MapChip(
                    icon: location.insideZone!
                        ? Icons.shield
                        : Icons.wrong_location,
                    label: location.insideZone! ? 'Inside safe zone' : 'Outside',
                    color: location.insideZone! ? Cg.green : Cg.red,
                  ),
                ),
              if (!location.hasPoint)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'No location fix yet. The patient phone shares location '
                      'while the app is open and consent is on.',
                      style: TextStyle(fontSize: 12, color: Cg.slate),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MapFrame extends StatelessWidget {
  const _MapFrame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: child,
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen map, opened from an alert or from the Location tab.
class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({super.key, required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('Live location'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: CaregiverRepo.patient(pid),
        builder: (context, snap) {
          final patient = snap.data?.data() ?? <String, dynamic>{};
          final location = PatientLocation.fromPatient(patient);

          return Column(
            children: [
              Expanded(
                child: LiveMapCard(pid: pid, height: double.infinity),
              ),
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.hasPoint
                          ? 'Last fix ${timeAgo(location.seen)} · '
                              '${location.accuracy == null ? 'accuracy unknown' : '±${location.accuracy!.round()} m'}'
                          : 'Waiting for the first location fix.',
                      style: const TextStyle(fontSize: 13, color: Cg.slate),
                    ),
                    if (location.distanceFromZone != null)
                      Text(
                        '${location.distanceFromZone!.round()} m from the safe '
                        'zone centre (limit ${location.radiusM?.round()} m).',
                        style: const TextStyle(fontSize: 13, color: Cg.slate),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Cg.navy,
                              minimumSize: const Size(0, 46),
                            ),
                            onPressed: location.hasPoint
                                ? () => openInMaps(
                                      location.point!.latitude,
                                      location.point!.longitude,
                                    )
                                : null,
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text('Open in Maps'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Map data © OpenStreetMap contributors. Location is '
                      'shared only while the patient allows it.',
                      style: TextStyle(fontSize: 11, color: Cg.muted),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
