// notification_permission_web.dart
import 'dart:html' as html;

Future<void> requestNotificationPermission() async {
  final permission = await html.window.navigator.permissions?.query({'name': 'notifications'});
  if (permission?.state != 'granted') {
    final result = await html.Notification.requestPermission();
    if (result != 'granted') {
      // Handle the case where the user denies the permission
      print('Notification permission denied');
    }
  }
}