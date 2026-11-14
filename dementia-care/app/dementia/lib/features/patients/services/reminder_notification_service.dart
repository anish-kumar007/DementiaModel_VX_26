import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReminderNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _tts = FlutterTts();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    // Updated to use the required 'settings' named parameter
    await _notifications.initialize(settings: initSettings);

    // Configure TTS for clear, calm voice readout for dementia patients
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  /// Speaks the reminder aloud so the patient does not have to read small text
  static Future<void> speakReminder(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TTS] Error speaking reminder: $e');
      }
    }
  }

  /// Triggers an immediate test notification (useful for hackathon demo)
  static Future<void> triggerImmediateDemoNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'patient_reminders_channel',
      'Daily Care Reminders',
      channelDescription: 'Medication and daily routine reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);

    // Updated to use required named parameters
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
    
    await speakReminder('$title. $body');
  }
}
