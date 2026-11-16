import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/companion_brain.dart';
import '../services/voice_assistant_service.dart';

/// The patient's helper: one big button to speak, big tap-able questions, and a
/// short answer that is also read aloud. Answers come from this phone, so it
/// works with no internet and no waiting.
class VoiceAssistantScreen extends StatefulWidget {
  final bool isHindi;
  const VoiceAssistantScreen({super.key, this.isHindi = false});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  static const _bg = Color(0xFF121619);

  late final stt.SpeechToText _speech = stt.SpeechToText();

  CompanionContext? _context;
  CompanionReply? _reply;
  bool _listening = false;
  bool _thinking = false;
  String _lastWords = '';
  String? _speechError;

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    VoiceAssistantService.initialize(isHindi: widget.isHindi);
    _loadContext();
  }

  Future<void> _loadContext() async {
    final context = await CompanionContext.load();
    if (!mounted) return;
    setState(() {
      _context = context;
      _reply ??= CompanionBrain.reply(
        widget.isHindi ? 'नमस्ते' : 'hello',
        context: context,
        isHindi: widget.isHindi,
      );
    });
  }

  List<String> get _suggestions {
    final reply = _reply;
    if (reply != null && reply.suggestions.isNotEmpty) return reply.suggestions;
    return CompanionBrain.suggestions(
      context: _context ?? const CompanionContext(),
      isHindi: widget.isHindi,
    );
  }

  Future<void> _startListening() async {
    setState(() {
      _speechError = null;
      _lastWords = '';
    });

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _speechError = _t(
              'I could not hear you. Please try again, or tap a question below.',
              'मैं सुन नहीं पाया। फिर कोशिश करें, या नीचे कोई सवाल दबाएँ।',
            );
          });
          if (kDebugMode) debugPrint('[ASSISTANT] speech error: ${error.errorMsg}');
        },
      );

      if (!available) {
        setState(() {
          _speechError = _t(
            'Speaking is not available on this phone. You can tap a question '
                'below instead.',
            'इस फ़ोन पर बोलना उपलब्ध नहीं है। आप नीचे कोई सवाल दबा सकते हैं।',
          );
        });
        return;
      }

      await VoiceAssistantService.stopSpeaking();
      setState(() => _listening = true);

      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: widget.isHindi ? 'hi_IN' : 'en_IN',
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          pauseFor: const Duration(seconds: 2),
        ),
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          setState(() => _lastWords = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            final said = result.recognizedWords.trim();
            _speech.stop();
            _handleQuery(said);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _speechError = _t(
          'I could not start listening. Please try again.',
          'सुनना शुरू नहीं हो सका। कृपया फिर कोशिश करें।',
        );
      });
      if (kDebugMode) debugPrint('[ASSISTANT] listen failed: $e');
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _handleQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _listening = false;
      _thinking = true;
      _lastWords = query;
      _speechError = null;
    });

    final reply = await VoiceAssistantService.ask(
      query: query,
      context: _context ?? const CompanionContext(),
      isHindi: widget.isHindi,
    );

    if (!mounted) return;
    setState(() {
      _reply = reply;
      _thinking = false;
    });

    await VoiceAssistantService.speak(reply.text);
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade900,
        title: Text(_t('Help & Talk', 'मदद और बातचीत')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                children: [
                  _HeroCard(isHindi: widget.isHindi),
                  const SizedBox(height: 16),
                  _ReplyCard(
                    reply: reply,
                    lastWords: _lastWords,
                    thinking: _thinking,
                    isHindi: widget.isHindi,
                    onCall: _call,
                    onSpeakAgain: reply == null
                        ? null
                        : () => VoiceAssistantService.speak(reply.text),
                  ),
                  if (_speechError != null) ...[
                    const SizedBox(height: 12),
                    _Notice(text: _speechError!),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _t('Tap a question', 'कोई सवाल दबाएँ'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final suggestion in _suggestions)
                        _SuggestionChip(
                          label: suggestion,
                          onTap: () => _handleQuery(suggestion),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _t(
                            'Works without internet. Answers come from this phone.',
                            'इंटरनेट के बिना भी काम करता है। जवाब इसी फ़ोन से आते हैं।',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: SizedBox(
                height: 86,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _listening ? Colors.amber.shade800 : Colors.teal.shade700,
                    disabledBackgroundColor: Colors.teal.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: _thinking
                      ? null
                      : (_listening ? _stopListening : _startListening),
                  icon: _thinking
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _listening ? Icons.stop_circle : Icons.mic,
                          size: 40,
                          color: Colors.white,
                        ),
                  label: Text(
                    _thinking
                        ? _t('ONE MOMENT...', 'एक पल...')
                        : (_listening
                            ? _t('LISTENING — TAP TO STOP', 'सुन रहा हूँ — रोकने के लिए दबाएँ')
                            : _t('TAP AND SPEAK', 'दबाएँ और बोलें')),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isHindi});

  final bool isHindi;

  String _t(String en, String hi) => isHindi ? hi : en;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, size: 34, color: Color(0xFF5EEAD4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('I am here with you', 'मैं आपके साथ हूँ'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Ask me the time, your medicines, your reminders, or to call someone.',
                    'मुझसे समय, अपनी दवा, रिमाइंडर, या किसी को कॉल करने के लिए कहें।',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.85),
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

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.lastWords,
    required this.thinking,
    required this.isHindi,
    required this.onCall,
    required this.onSpeakAgain,
  });

  final CompanionReply? reply;
  final String lastWords;
  final bool thinking;
  final bool isHindi;
  final Future<void> Function(String phone) onCall;
  final VoidCallback? onSpeakAgain;

  String _t(String en, String hi) => isHindi ? hi : en;

  @override
  Widget build(BuildContext context) {
    final r = reply;
    final callPhone = r?.callPhone;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF5EEAD4).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lastWords.isNotEmpty) ...[
            Text(
              '${_t('You said', 'आपने कहा')}: “$lastWords”',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 10),
          ],
          if (thinking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
              ),
            )
          else
            Text(
              r?.text ??
                  _t(
                    'Tap the big button and tell me what you need.',
                    'बड़ा बटन दबाएँ और बताएँ कि आपको क्या चाहिए।',
                  ),
              style: const TextStyle(
                fontSize: 22,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          if (!thinking && callPhone != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => onCall(callPhone),
                icon: const Icon(Icons.call, size: 28, color: Colors.white),
                label: Text(
                  _t('Call ${r?.callName ?? 'now'}', '${r?.callName ?? ''} को कॉल करें'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          if (!thinking && r != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSpeakAgain,
                icon: const Icon(Icons.volume_up, size: 20, color: Color(0xFF5EEAD4)),
                label: Text(
                  _t('Read again', 'फिर सुनें'),
                  style: const TextStyle(color: Color(0xFF5EEAD4)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blueGrey.shade900,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.question_answer, size: 18, color: Color(0xFF5EEAD4)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
