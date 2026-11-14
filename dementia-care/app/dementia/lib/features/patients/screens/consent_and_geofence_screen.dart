import 'package:material_ui/material_ui.dart';

class ConsentAndGeofenceScreen extends StatefulWidget {
  const ConsentAndGeofenceScreen({super.key});

  @override
  State<ConsentAndGeofenceScreen> createState() => _ConsentAndGeofenceScreenState();
}

class _ConsentAndGeofenceScreenState extends State<ConsentAndGeofenceScreen> {
  bool _consentGiven = true;
  bool _isInsideSafeZone = true;
  bool _isChecking = false;
  String _locationStatus = 'Inside Safe Zone (Home)';

  Future<void> _runDemoGeofenceTest(bool simulateOutside) async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isChecking = false;
      _isInsideSafeZone = !simulateOutside;
      _locationStatus = _isInsideSafeZone
          ? 'Inside Safe Zone (Home)'
          : 'WARNING: Outside Safe Zone! Caregiver alerted.';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isInsideSafeZone ? 'Demo: Patient is safe at home.' : 'Demo: Geofence breach simulated!',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _isInsideSafeZone ? Colors.teal.shade700 : Colors.red.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Zone & Consent'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isInsideSafeZone ? Colors.teal.shade900 : Colors.red.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    _isInsideSafeZone ? Icons.verified_user : Icons.warning_amber_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _locationStatus,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Consent Toggle
            SwitchListTile(
              title: const Text('Background Location Tracking Consent', style: TextStyle(fontSize: 20)),
              subtitle: const Text('Allows caregiver to monitor safety zones.', style: TextStyle(fontSize: 16, color: Colors.white60)),
              value: _consentGiven,
              activeThumbColor: Colors.tealAccent,
              onChanged: (val) {
                setState(() => _consentGiven = val);
              },
            ),
            const Divider(height: 40, color: Colors.white24),
            const Text(
              'Hackathon Demo Geofence Triggers:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ).wrapElevatedButton(
              onPressed: _isChecking ? null : () => _runDemoGeofenceTest(false),
              child: const Text('Simulate Inside Safe Zone', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ).wrapElevatedButton(
              onPressed: _isChecking ? null : () => _runDemoGeofenceTest(true),
              child: const Text('Simulate Geofence Breach (Outside)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

extension on ButtonStyle {
  Widget wrapElevatedButton({required VoidCallback? onPressed, required Widget child}) {
    return ElevatedButton(style: this, onPressed: onPressed, child: child);
  }
}
