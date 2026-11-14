// app/lib/caregiver/push/push_handler.dart
// Shows alert pushes while the app is open, and opens the alert on tap.
// B already saves the FCM token and asks notification permission (core).
//
// ASSUMPTION: send_alert_push puts these keys in the message DATA:
//   pid, alertId, type. Confirm with A. If A sends data-only messages, also add
// a top-level background handler in main.dart (see SETUP.md).
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
        _open(nav, Map<String, dynamic>.from(jsonDecode(r.payload!)));
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // App open: FCM does not show a banner itself, so show one.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      final title = n?.title ?? _title(m.data);
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
        payload: jsonEncode(m.data),
      );
    });

    // App in background, user taps the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(nav, m.data));

    // App was closed, user tapped the notification to start it.
    final first = await FirebaseMessaging.instance.getInitialMessage();
    if (first != null) _open(nav, first.data);
  }

  static String _title(Map<String, dynamic> d) =>
      alertLabel(d['type'] as String?);

  static void _open(NavigatorState nav, Map<String, dynamic> d) {
    final pid = d['pid'] as String?;
    if (pid == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) =>
          AlertsScreen(pid: pid, highlightId: d['alertId'] as String?),
    ));
  }
}