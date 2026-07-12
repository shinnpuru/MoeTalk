import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math' show Random;

// Conditional import
import 'non_web_utils.dart'
    if (dart.library.html) 'web_utils.dart';

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await requestNotificationPermission();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(
      {required String title, required String body, bool showAvator=true}) async {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('shinnpuru.moetalk.notification', 'notification',
            channelDescription: 'Message notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: "@mipmap/ic_launcher",
            visibility: NotificationVisibility.public,
            largeIcon: showAvator ? const DrawableResourceAndroidBitmap("head_round"):null,
            ticker: 'message');
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidNotificationDetails);
    await _notificationsPlugin.show(
      Random().nextInt(10000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
