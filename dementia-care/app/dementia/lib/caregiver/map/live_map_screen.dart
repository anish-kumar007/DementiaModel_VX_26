import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../common.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key, required this.pid});
  final String pid;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _map = MapController();
  LatLng? _lastKnownPos; // FUNCTIONAL FIX: Tracks actual position changes to prevent rebuild loops

  LatLng? _point(Map<String, dynamic>? m) {
    if (m == null || m['lat'] == null || m['lng'] == null) return null;
    return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live location')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: patientRef(widget.pid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final p = snap.data!.data() ?? {};
          final last = p['lastLocation'] as Map<String, dynamic>?;
          final pos = _point(last);
          final zone = p['safeZone'] as Map<String, dynamic>?;
          final zoneCentre = _point(zone);
          final radius = (zone?['radiusM'] as num?)?.toDouble();

          final centre = pos ?? zoneCentre;
          if (centre == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No location yet. It appears once the patient phone shares its location.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // FUNCTIONAL FIX: Only move the map if the position has ACTUALLY changed
          if (pos != null && pos != _lastKnownPos) {
            _lastKnownPos = pos;
            // Use addPostFrameCallback to avoid "setState during build" errors
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _map.move(pos, _map.camera.zoom);
              }
            });
          }

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(initialCenter: centre, initialZoom: 16),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.dementia_care',
                    ),
                    if (zoneCentre != null && radius != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: zoneCentre,
                          radius: radius,
                          useRadiusInMeter: true,
                          color: const Color(0x332E7D32),
                          borderColor: const Color(0xFF2E7D32),
                          borderStrokeWidth: 2,
                        ),
                      ]),
                    if (pos != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: pos,
                          width: 48,
                          height: 48,
                          child: const Icon(Icons.location_on, size: 48, color: Color(0xFFC62828)),
                        ),
                      ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  pos == null
                      ? 'Showing the safe zone. No location reading yet.'
                      : 'Updated ${timeAgo(toDate(last?['time']) ?? DateTime.now())}'
                          '${zone == null ? '  ·  No safe zone set (see Settings)' : ''}',
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Map data © OpenStreetMap contributors', style: TextStyle(fontSize: 11)),
              ),
            ],
          );
        },
      ),
    );
  }
}