import 'package:material_ui/material_ui.dart';

class ConsentAndGeofenceScreen extends StatefulWidget {
  final bool isHindi;
  const ConsentAndGeofenceScreen({super.key, this.isHindi = false});

  @override
  State<ConsentAndGeofenceScreen> createState() => _ConsentAndGeofenceScreenState();
}

class _ConsentAndGeofenceScreenState extends State<ConsentAndGeofenceScreen> {
  bool _consentGiven = true;
  bool _isInsideSafeZone = true;
  bool _isChecking = false;
  int _outsideReadingsCount = 0;

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  Future<void> _runDemoGeofenceTest(bool simulateOutside) async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!simulateOutside) {
      setState(() {
        _outsideReadingsCount = 0;
        _isInsideSafeZone = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Inside Safe Zone (Home).', 'सुरक्षित क्षेत्र (घर) के अंदर हैं।'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade700,
        ),
      );
      return;
    }

    // Two readings outside safeZone trigger "Are you okay?" prompt
    setState(() => _outsideReadingsCount += 1);

    if (_outsideReadingsCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Reading 1/2 outside zone. Checking again...', 'क्षेत्र से बाहर पहली रीडिंग (1/2)। पुनः जाँच हो रही है...'),
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      return;
    }

    setState(() => _isInsideSafeZone = false);
    _showAreYouOkayPrompt();
  }

  Future<void> _showAreYouOkayPrompt() async {
    final isOkay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('Are you okay?', 'क्या आप ठीक हैं?'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amberAccent),
        ),
        content: Text(
          _t(
            'You appear to be outside your safe zone. Tap "I am okay" or we will notify your caregiver.',
            'आप अपने सुरक्षित क्षेत्र से बाहर लग रहे हैं। "मैं ठीक हूँ" दबाएँ, अन्यथा हम आपके देखभालकर्ता को सूचित करेंगे।',
          ),
          style: const TextStyle(fontSize: 20, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t('Notify Caregiver', 'देखभालकर्ता को बताएं'),
              style: const TextStyle(fontSize: 18, color: Colors.amberAccent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t('I am okay', 'मैं ठीक हूँ'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (isOkay == true) {
      setState(() {
        _outsideReadingsCount = 0;
        _isInsideSafeZone = true;
      });
    } else {
      // TODO: Write alert doc of type 'geofence' to patients/{pid}/alerts
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Caregiver alerted about Safe Zone exit.', 'सुरक्षित क्षेत्र से बाहर जाने की सूचना देखभालकर्ता को भेज दी गई है।'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Safe Zone & Consent', 'सुरक्षित क्षेत्र और सहमति')),
        backgroundColor: Colors.teal.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permanent Location Sharing Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _consentGiven ? Colors.teal.shade900.withOpacity(0.6) : Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _consentGiven ? Colors.tealAccent : Colors.white38),
              ),
              child: Row(
                children: [
                  Icon(
                    _consentGiven ? Icons.my_location : Icons.location_disabled,
                    color: _consentGiven ? Colors.tealAccent : Colors.white70,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _consentGiven
                          ? _t('Location Sharing is ON', 'लोकेशन शेयरिंग चालू है')
                          : _t('Location Sharing is PAUSED', 'लोकेशन शेयरिंग रुकी हुई है'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Safe Zone Status Card (Calm teal/amber palette — no red)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _isInsideSafeZone ? Colors.teal.shade900 : Colors.amber.shade900,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(
                    _isInsideSafeZone ? Icons.verified_user : Icons.explore_off,
                    size: 52,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isInsideSafeZone
                        ? _t('Inside Safe Zone (Home)', 'सुरक्षित क्षेत्र (घर) के अंदर')
                        : _t('Outside Safe Zone • Caregiver Notified', 'सुरक्षित क्षेत्र से बाहर • देखभालकर्ता को सूचित किया गया'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Consent Switch
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                _t('Share Location with Caregiver', 'देखभालकर्ता के साथ लोकेशन साझा करें'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Text(
                _t('Helps family support you if you walk out alone.', 'अकेले बाहर जाने पर परिवार को आपकी मदद करने में सहायक।'),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              value: _consentGiven,
              activeThumbColor: Colors.tealAccent,
              onChanged: (val) => setState(() => _consentGiven = val),
            ),
            const Divider(height: 32, color: Colors.white24),

            // Demo Geofence Triggers
            Text(
              _t('Demo Safe Zone Check:', 'डेमो सुरक्षित क्षेत्र जाँच:'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 62,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isChecking ? null : () => _runDemoGeofenceTest(false),
                child: Text(
                  _t('Simulate Inside Safe Zone', 'सुरक्षित क्षेत्र के अंदर दिखाएँ'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 62,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isChecking ? null : () => _runDemoGeofenceTest(true),
                child: Text(
                  _t('Simulate Walking Out (${_outsideReadingsCount}/2)', 'बाहर निकलने का डेमो (${_outsideReadingsCount}/2)'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
