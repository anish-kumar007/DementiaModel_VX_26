import 'package:flutter/foundation.dart';

class SessionLogger {
  /// Logs game session metrics matching Firestore schema:
  /// patients/{pid}/sessions/{id} ->
  /// {game, level, accuracy, avgResponseMs, language, timestamp}
  static Future<void> logSession({
    required String game,
    required int level,
    required double accuracy,
    required int avgResponseMs,
    required String language,
  }) async {
    final sessionData = {
      'game': game,
      'level': level,
      'accuracy': double.parse(accuracy.toStringAsFixed(2)),
      'avgResponseMs': avgResponseMs,
      'language': language,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('[SESSION LOG] Ready for Firestore queue: $sessionData');
    }

    // Firestore offline persistence automatically queues writes when offline:
    // await FirebaseFirestore.instance
    //     .collection('patients')
    //     .doc(pid)
    //     .collection('sessions')
    //     .add(sessionData);
  }
}
