import 'package:flutter/foundation.dart';

class SessionLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('Session Log: $message');
    }
  }
}