// app/lib/caregiver/settings/safe_zone_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../common.dart';

class SafeZoneScreen extends StatefulWidget {
  const SafeZoneScreen({super.key, required this.pid});
  final String pid;
  @override
  State<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends State<SafeZoneScreen> {
  LatLng? _centre;
  double _radius = 200; // metres
  bool _loaded = false;
  bool _saving = false;

  // Fallback map centre (New Delhi) if nothing is known yet.
  static const _fallback = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = (await patientRef(widget.pid).get()).data() ?? {};
    final z = p['safeZone'] as Map<String, dynamic>?;
    final loc = p['lastLocation'] as Map<String, dynamic>?;
    LatLng? c;
    if (z?['lat'] != null && z?['lng'] != null) {
      c = LatLng((z!['lat'] as num).toDouble(), (z['lng'] as num).toDouble());
      _radius = ((z['radiusM'] as num?) ?? 200).toDouble();
    } else if (loc?['lat'] != null && loc?['lng'] != null) {
      c = LatLng(
          (loc!['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
    }
    if (!mounted) return;
    setState(() {
      _centre = c;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (_centre == null) {
      snack(context, 'Tap the map to choose the centre first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await patientRef(widget.pid).update({
        'safeZone': {
          'lat': _centre!.latitude,
          'lng': _centre!.longitude,
          'radiusM': _radius.round(),
        },
      });
      if (mounted) {
        snack(context, 'Safe zone saved.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) snack(context, 'Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
          appBar: AppBar(title: const Text('Safe zone')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Safe zone')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _centre ?? _fallback,
                initialZoom: 16,
                onTap: (_, point) => setState(() => _centre = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.dementia_care',
                ),
                if (_centre != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: _centre!,
                      radius: _radius,
                      useRadiusInMeter: true,
                      color: const Color(0x332E7D32),
                      borderColor: const Color(0xFF2E7D32),
                      borderStrokeWidth: 2,
                    ),
                  ]),
                if (_centre != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _centre!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.home,
                          size: 36, color: Color(0xFF2E7D32)),
                    ),
                  ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_centre == null
                    ? 'Tap the map to choose the centre.'
                    : 'Radius: ${_radius.round()} m'),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  label: '${_radius.round()} m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Save safe zone'),
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