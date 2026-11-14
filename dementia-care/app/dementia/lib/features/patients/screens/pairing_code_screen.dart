import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';

class PairingCodeScreen extends StatefulWidget {
  final bool isHindi;
  const PairingCodeScreen({super.key, this.isHindi = false});

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  String _pairingCode = '482-910';
  bool _isLoading = false;
  int _secondsRemaining = 600; // 10 minutes
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsRemaining = 600;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTimer {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _refreshCode() async {
    setState(() => _isLoading = true);
    // TODO: Call FirebaseFunctions.instance.httpsCallable('create_pairing_code')
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final rand = Random();
    final p1 = (100 + rand.nextInt(900)).toString();
    final p2 = (100 + rand.nextInt(900)).toString();

    setState(() {
      _pairingCode = '$p1-$p2';
      _isLoading = false;
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _secondsRemaining == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Link Caregiver', 'देखभालकर्ता जोड़ें')),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(
                'Ask your caregiver to enter this 6-digit code on their phone:',
                'अपने देखभालकर्ता से यह 6-अंकों का कोड उनके फ़ोन पर डालने के लिए कहें:',
              ),
              style: const TextStyle(fontSize: 22, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isExpired ? Colors.amberAccent : Colors.tealAccent,
                  width: 2,
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                  : Column(
                      children: [
                        Text(
                          isExpired ? _t('EXPIRED', 'समय समाप्त') : _pairingCode,
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                            color: isExpired ? Colors.amberAccent : Colors.tealAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isExpired
                              ? _t('Tap below for a new code', 'नए कोड के लिए नीचे दबाएँ')
                              : _t('Expires in $_formattedTimer', '$_formattedTimer में समाप्त होगा'),
                          style: const TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _refreshCode,
                icon: const Icon(Icons.refresh, size: 32, color: Colors.white),
                label: Text(
                  _t('Generate New Code', 'नया कोड बनाएँ'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
