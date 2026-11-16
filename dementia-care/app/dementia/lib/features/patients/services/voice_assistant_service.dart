import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../services/patient_writes.dart';
import 'companion_brain.dart';

/// Speaks and answers for the patient. Answers are produced on the device by
/// [CompanionBrain] (instant, offline, no API key). Each turn is mirrored into
/// patients/{pid}/assistantChats so a caregiver can see what was asked.
class VoiceAssistantService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> initialize({bool isHindi = false}) async {
    await setLanguage(isHindi: isHindi);
  }

  static Future<void> setLanguage({required bool isHindi}) async {
    await _tts.setLanguage(isHindi ? 'hi-IN' : 'en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  static Future<CompanionReply> ask({
    required String query,
    required CompanionContext context,
    required bool isHindi,
  }) async {
    final reply = CompanionBrain.reply(query, context: context, isHindi: isHindi);

    try {
      await PatientWrites.logAssistantTurn(
        question: query,
        reply: reply.text,
        language: isHindi ? 'hi' : 'en',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ASSISTANT] Could not log the turn: $e');
    }

    return reply;
  }

  static Future<void> speak(String text) async {
    await _tts.stop();
    final hasHindiScript = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    await _tts.setLanguage(hasHindiScript ? 'hi-IN' : 'en-US');
    await _tts.speak(text);
  }

  static Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
