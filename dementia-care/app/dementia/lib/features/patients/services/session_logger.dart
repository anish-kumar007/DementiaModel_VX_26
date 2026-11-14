import 'package:flutter/foundation.dart';

class SessionLogger {
  static void logSession({
    required String gameName,
    required int score,
    required int difficultyLevel,
    required bool completed,
  }) {
    if (kDebugMode) {
      debugPrint(
        '[SESSION LOG] Game: $gameName| Score: $score| Level: $difficultyLevel, Completed: $completed',
      );
    }
    //TODO: Sync To Firestore or local Hive/SharedPreferences cache if offline and sync when online
  }
}
