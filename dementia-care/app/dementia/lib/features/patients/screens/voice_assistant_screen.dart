import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/voice_assistant_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = 'Tap the microphone and ask me anything...';
  String _aiResponse = 'I am your Care Companion assistant.';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await VoiceAssistantService.initialize();
    if (!mounted) return;
    setState(() {});
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) async {
          setState(() {
            _lastWords = val.recognizedWords;
          });
          if (val.finalResult && val.recognizedWords.isNotEmpty) {
            _handleUserQuery(val.recognizedWords);
          }
        },
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _handleUserQuery(String query) async {
    setState(() {
      _isListening = false;
      _isLoading = true;
    });

    final response = await VoiceAssistantService.getAiCompanionResponse(query);

    if (!mounted) return;
    setState(() {
      _aiResponse = response;
      _isLoading = false;
    });

    await VoiceAssistantService.speak(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Colors.indigo.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Response Card
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.tealAccent, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.support_agent, size: 64, color: Colors.tealAccent),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.tealAccent)
                        : Text(
                            _aiResponse,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // User Spoken Words Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'You said: "$_lastWords"',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            // Microphone Button
            SizedBox(
              height: 90,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red.shade700 : Colors.teal.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 6,
              ),
              onPressed: _isListening ? _stopListening : _startListening,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isListening ? Icons.mic : Icons.mic_none, size: 40, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    _isListening ? 'LISTENING... (TAP TO STOP)' : 'TAP TO SPEAK',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
        )],
        ),
      ),
    );
  }
}

extension on ButtonStyle {
  Widget wrapElevatedButton({required VoidCallback onPressed, required Widget child}) {
    return ElevatedButton(style: this, onPressed: onPressed, child: child);
  }
}
