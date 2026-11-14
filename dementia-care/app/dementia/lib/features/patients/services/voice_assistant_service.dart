import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  static final FlutterTts _tts = FlutterTts();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initializes TTS (STT is handled in the screen to avoid conflicts)
  static Future<void> initialize({bool isHindi = false}) async {
    await setLanguage(isHindi: isHindi);
  }

  static Future<void> setLanguage({required bool isHindi}) async {
    // en-US is generally more reliable for TTS engines than en-IN
    await _tts.setLanguage(isHindi ? 'hi-IN' : 'en-US');
    await _tts.setSpeechRate(0.45); // Calm, slow pace for dementia care
    await _tts.setVolume(1.0);
  }

  /// The main entry point called from the screen.
  static Future<VoiceAssistantResponse> getAiCompanionResponse({
    required String userQuery,
    required String uid,
    bool isHindi = false,
  }) async {
    final fallback = VoiceAssistantResponse(
      reply: isHindi
          ? 'मैं यहीं आपके साथ हूँ। सब ठीक है, आप आराम करें।'
          : 'I am right here with you. Everything is alright, take a gentle breath.',
      action: 'none',
    );

    try {
      // 1. Write request to Firestore
      final requestId = await _sendRequestToAI(
        uid: uid,
        text: userQuery,
        language: isHindi ? 'hi' : 'en',
      );

      // 2. Wait for Python backend to process and update the document
      final result = await _waitForAIResponse(requestId);
      
      // 3. Parse action from reply if the backend signals it (e.g., "call:Aarav")
      final lowerReply = result.reply.toLowerCase();
      final action = lowerReply.startsWith('call:') ? lowerReply : 'none';

      return VoiceAssistantResponse(
        reply: result.reply,
        action: action,
      );

    } catch (e) {
      if (kDebugMode) debugPrint('[AI CHAT] Error or Timeout: $e');
      return fallback;
    }
  }

  /// STEP 1: Create the pending document
  static Future<String> _sendRequestToAI({
    required String uid,
    required String text,
    required String language,
  }) async {
    final docRef = await _firestore.collection('assistantRequests').add({
      'uid': uid,
      'text': text,
      'language': language,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// STEP 2: Listen for the Python backend to flip status to 'completed'
  static Future<VoiceAssistantResponse> _waitForAIResponse(String requestId) async {
    final completer = Completer<VoiceAssistantResponse>();
    late final StreamSubscription<DocumentSnapshot> sub;
    late final Timer timer;

    sub = _firestore
        .collection('assistantRequests')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;

      if (data['status'] == 'completed') {
        if (!completer.isCompleted) {
          completer.complete(
            VoiceAssistantResponse(
              reply: (data['reply'] ?? "I am here with you.").toString(),
              action: 'none',
            ),
          );
        }
      } else if (data['status'] == 'error') {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(data['errorMessage'] ?? 'Backend processing failed'),
          );
        }
      }
    });

    // 15-second timeout to prevent hanging if Python server is slow/offline
    timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('AI response timed out'));
      }
    });

    try {
      final result = await completer.future;
      return result;
    } finally {
      timer.cancel();
      await sub.cancel(); // CRITICAL: prevents memory leaks from dangling listeners
    }
  }

  /// STEP 3: Speak the reply, auto-detecting Hindi/English
  static Future<void> speak(String text) async {
    await _tts.stop();
    
    final isHindi = text.contains('मैं') || text.contains('नमस्ते') || text.contains('आप');
    await _tts.setLanguage(isHindi ? "hi-IN" : "en-US");
    
    await _tts.speak(text);
  }
}