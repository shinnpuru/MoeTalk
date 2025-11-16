// notification_permission_stub.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
    var permission = await Permission.notification.status;
    if (!permission.isGranted) {
      await Permission.notification.request();
    }
}

Future<bool> writeFile(String data) async {
  if (Platform.isAndroid) {
    return await writeFileAndroid(data);
  } else if (Platform.isWindows) {
    return await writeFileWindows(data);
  } else {
    debugPrint('Unsupported platform');
    return false;
  }
}

Future<bool> writePngFile(Uint8List outputBytes) async {
  try {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '请保存角色卡',
      fileName: 'momoAvatar_${DateTime.now().millisecondsSinceEpoch}.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(outputBytes);
    }
    return true;
  } catch (e) {
    debugPrint('Error writing PNG file: $e');
    return false;
  }
}

Future<bool> writeFileAndroid(String data) async {
  var status = await Permission.manageExternalStorage.status;
  if (!status.isGranted) {
    status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      debugPrint('MANAGE_EXTERNAL_STORAGE permission denied');
      return false;
    }
  }
  try {
    String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    File file = File('/storage/emulated/0/Download/momoBackup_$timeStamp.json');
    await file.writeAsString(data);
    debugPrint('write file: ${file.path}');
    return true;
  } catch (e) {
    debugPrint('Error writing file: $e');
    return false;
  }
}

Future<bool> writeFileWindows(String data) async {
  try {
    Directory? directory = await getDownloadsDirectory();
    String path = directory?.path ?? '';
    String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    File file = File('$path/momoBackup_$timeStamp.json');
    await file.writeAsString(data);
    debugPrint('write file: ${file.path}');
    return true;
  } catch (e) {
    debugPrint('Error writing file: $e');
    return false;
  }
}