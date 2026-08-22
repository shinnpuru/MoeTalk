import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'utils.dart';

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
  return _saveBytes(
    outputBytes,
    dialogTitle: '请保存角色卡',
    fileName:
        'MoeAvatar_${getTimeStr(DateTime.now().millisecondsSinceEpoch)}.png',
    allowedExtension: 'png',
  );
}

Future<bool> _saveBytes(
  Uint8List bytes, {
  required String dialogTitle,
  required String fileName,
  required String allowedExtension,
}) async {
  try {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [allowedExtension],
      bytes: Platform.isAndroid || Platform.isIOS ? bytes : null,
    );

    if (outputFile == null) {
      return false;
    }

    // On mobile, file_picker writes the bytes through the system document URI.
    // Desktop implementations only return a path, so write the file here.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(outputFile).writeAsBytes(bytes);
    }
    return true;
  } catch (e) {
    debugPrint('Error saving file: $e');
    return false;
  }
}

Future<bool> writeFileAndroid(String data) async {
  final timeStamp = getTimeStr(DateTime.now().millisecondsSinceEpoch);
  return _saveBytes(
    Uint8List.fromList(utf8.encode(data)),
    dialogTitle: '请保存备份文件',
    fileName: 'MoeBackup_$timeStamp.json',
    allowedExtension: 'json',
  );
}

Future<bool> writeFileWindows(String data) async {
  try {
    Directory? directory = await getDownloadsDirectory();
    String path = directory?.path ?? '';
    String timeStamp = getTimeStr(DateTime.now().millisecondsSinceEpoch);
    File file = File('$path/MoeBackup_$timeStamp.json');
    await file.writeAsString(data);
    debugPrint('write file: ${file.path}');
    return true;
  } catch (e) {
    debugPrint('Error writing file: $e');
    return false;
  }
}
