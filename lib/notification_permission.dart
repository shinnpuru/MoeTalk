// notification_permission_stub.dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
    var permission = await Permission.notification.status;
    if (!permission.isGranted) {
      await Permission.notification.request();
    }
}