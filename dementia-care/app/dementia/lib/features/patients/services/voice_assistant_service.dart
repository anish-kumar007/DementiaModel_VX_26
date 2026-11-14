import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();

  static Future<bool> initialize() async {
    bool available = await _speech.initialize(
      onError: (val) => debugPrint('[STT Error]: $val'),
      onStatus: (val) => debugPrint('[STT Status]: $val'),
    );
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    return available;
  }

  /// Sends prompt to Member A's assistant_chat endpoint (Cloud Function)
  static Future<String> getAiCompanionResponse(String userQuery) async {
    try {
      if (kDebugMode) {
        debugPrint('[AI CHAT] Querying assistant_chat with: $userQuery');
      }
      // TODO: Replace with actual FirebaseFunctions.instance.httpsCallable('assistant_chat').call({'prompt': userQuery})
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate 8 second timeout rule / network
      
      // Kind fallback response per plan specs
      if (userQuery.toLowerCase().contains('where') || userQuery.toLowerCase().contains('home')) {
        return 'You are safe at home with your family. Everything is alright.';
      }
      return 'I am here with you. Let us take a gentle breath and relax.';
    } catch (e) {
      return 'I am here for you. You are doing great.';
    }
  }

  static Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }
}
