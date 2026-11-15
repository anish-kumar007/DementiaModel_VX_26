import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// FUNCTIONAL FIX: Import the helpers directly to avoid circular dependency risks
import '../alerts/alerts_screen.dart'; 

class CaregiverPush {
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'alerts',
    'Alerts',
    description: 'SOS and safe zone alerts',
    importance: Importance.max,
  );

  static Future<void> init(BuildContext context) async {
    if (_ready) return;
    _ready = true;
    final nav = Navigator.of(context);

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == null) return;
        try {
          // FUNCTIONAL FIX: Safe JSON decoding
          final data = Map<String, dynamic>.from(jsonDecode(r.payload!));
          _open(nav, data);
        } catch (e) {
          debugPrint('Push payload decode error: $e');
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 1. App open: FCM does not show a banner itself, so show one locally.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      final data = m.data;
      final title = n?.title ?? _title(data);
      final body = n?.body ?? 'Open the app to see details.';
      
      _local.show(
        id: m.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(data),
      );
    });

    // 2. App in background, user taps the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(nav, m.data));

    // 3. App was closed, user tapped the notification to start it.
    final first = await FirebaseMessaging.instance.getInitialMessage();
    if (first != null) {
      // FUNCTIONAL FIX: Slight delay ensures Navigator is mounted after cold start
      Future.delayed(const Duration(milliseconds: 500), () => _open(nav, first.data));
    }
  }

  static String _title(Map<String, dynamic> d) => alertLabel(d['type'] as String?);

  static void _open(NavigatorState nav, Map<String, dynamic> d) {
    // FUNCTIONAL FIX: Strict null/empty checking for pid
    final pid = d['pid'] as String?;
    if (pid == null || pid.isEmpty) {
      debugPrint('Push notification missing valid pid: $d');
      return;
    }
    
    nav.push(MaterialPageRoute(
      builder: (_) => AlertsScreen(
        pid: pid, 
        highlightId: d['alertId'] as String?,
      ),
    ));
  }
}