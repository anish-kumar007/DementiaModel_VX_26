import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantResponse {
  final String reply;
  final String action; // 'none' or 'call:<name>'

  const VoiceAssistantResponse({
    required this.reply,
    this.action = 'none',
  });
}

class VoiceAssistantService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();

  static Future<bool> initialize({bool isHindi = false}) async {
    final available = await _speech.initialize(
      onError: (val) => debugPrint('[STT Error]: $val'),
      onStatus: (val) => debugPrint('[STT Status]: $val'),
    );
    await setLanguage(isHindi: isHindi);
    return available;
  }

  static Future<void> setLanguage({required bool isHindi}) async {
    await _tts.setLanguage(isHindi ? 'hi-IN' : 'en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  /// Calls Member A's `assistant_chat` callable with {text, language, history},
  /// enforces an 8-second timeout, and returns structured {reply, action}.
  static Future<VoiceAssistantResponse> getAiCompanionResponse({
    required String userQuery,
    bool isHindi = false,
    List<Map<String, String>> history = const [],
  }) async {
    final fallback = VoiceAssistantResponse(
      reply: isHindi
          ? 'मैं यहीं आपके साथ हूँ। सब ठीक है, आप आराम करें।'
          : 'I am right here with you. Everything is alright, take a gentle breath.',
      action: 'none',
    );

    try {
      return await _callAssistantFunction(
        text: userQuery,
        language: isHindi ? 'hi' : 'en',
        history: history,
      ).timeout(const Duration(seconds: 8), onTimeout: () => fallback);
    } catch (e) {
      if (kDebugMode) debugPrint('[AI CHAT] Error: $e');
      return fallback;
    }
  }

  static Future<VoiceAssistantResponse> _callAssistantFunction({
    required String text,
    required String language,
    required List<Map<String, String>> history,
  }) async {
    if (kDebugMode) {
      debugPrint('[AI CHAT] Calling assistant_chat ($language): $text');
    }

    // TODO: Replace stub with FirebaseFunctions.instance.httpsCallable('assistant_chat').call({
    //   'text': text,
    //   'language': language,
    //   'history': history,
    // });
    await Future.delayed(const Duration(milliseconds: 600));

    final lower = text.toLowerCase();
    if (lower.contains('call ') || lower.contains('कॉल')) {
      final target = lower.contains('doctor') || lower.contains('डॉक्टर')
          ? 'Doctor'
          : 'Aarav';
      return VoiceAssistantResponse(
        reply: language == 'hi'
            ? '$target को कॉल लगा रहे हैं।'
            : 'Calling $target for you now.',
        action: 'call:$target',
      );
    }

    if (lower.contains('where') || lower.contains('home') || lower.contains('कहाँ')) {
      return VoiceAssistantResponse(
        reply: language == 'hi'
            ? 'आप घर पर सुरक्षित हैं। सब कुछ ठीक है।'
            : 'You are safe at home with your family. Everything is alright.',
        action: 'none',
      );
    }

    return VoiceAssistantResponse(
      reply: language == 'hi'
          ? 'मैं यहीं आपके साथ हूँ। क्या आप अपने परिवार से बात करना चाहेंगे?'
          : 'I am here with you. Would you like to check your reminders or call family?',
      action: 'none',
    );
  }

  static Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }
}
