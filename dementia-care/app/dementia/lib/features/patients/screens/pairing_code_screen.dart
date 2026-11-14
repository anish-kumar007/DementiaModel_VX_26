import 'package:material_ui/material_ui.dart';
class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({super.key});

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  // Generated via Member A's create_pairing_code Cloud Function
  String _pairingCode = '482-910';
  bool _isLoading = false;

  Future<void> _refreshCode() async {
    setState(() => _isLoading = true);
    // TODO: Call FirebaseFunctions.instance.httpsCallable('create_pairing_code')
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _pairingCode = '735-204';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Caregiver'),
        backgroundColor: Colors.blueGrey.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ask your caregiver to enter this code on their phone:',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.tealAccent, width: 2),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      _pairingCode,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: Colors.tealAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _refreshCode,
              icon: const Icon(Icons.refresh, size: 32),
              label: const Text('Generate New Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
