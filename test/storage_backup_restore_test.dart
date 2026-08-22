import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/display_settings_defaults.dart';
import 'package:moetalk/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup always contains effective display settings', () async {
    SharedPreferences.setMockInitialValues({
      'display_font_size': 26.0,
    });

    final backup = jsonDecode(await convertToJson()) as Map<String, dynamic>;

    expect(backup['display_font_size'], 26.0);
    expect(backup['display_text_color'], defaultDisplayTextColorHex);
    expect(backup['display_name_color'], defaultDisplayNameColorHex);
    expect(backup['display_text_outline'], defaultDisplayTextOutline);
    expect(backup['display_outline_width'], defaultDisplayOutlineWidth);
    expect(backup['display_outline_color'], defaultDisplayOutlineColorHex);
  });

  test('restores supported preference values from a backup', () async {
    SharedPreferences.setMockInitialValues({'existing': 'old'});

    await restoreFromJson(jsonEncode({
      'name': 'Misono',
      'count': 3,
      'ratio': 0.5,
      'enabled': true,
      'items': ['one', 'two'],
    }));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get('existing'), isNull);
    expect(prefs.getString('name'), 'Misono');
    expect(prefs.getInt('count'), 3);
    expect(prefs.getDouble('ratio'), 0.5);
    expect(prefs.getBool('enabled'), isTrue);
    expect(prefs.getStringList('items'), ['one', 'two']);
  });

  test('does not clear preferences when the backup is invalid', () async {
    SharedPreferences.setMockInitialValues({'existing': 'keep'});

    await expectLater(
      restoreFromJson(jsonEncode(['not', 'an', 'object'])),
      throwsFormatException,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('existing'), 'keep');
  });

  test('reads a large picked backup as a stream', () async {
    final content = jsonEncode({
      'payload': List<String>.filled(5 * 1024 * 1024, 'x').join(),
    });
    final bytes = utf8.encode(content);
    final chunks = <List<int>>[];
    for (var offset = 0; offset < bytes.length; offset += 64 * 1024) {
      final end =
          offset + 64 * 1024 < bytes.length ? offset + 64 * 1024 : bytes.length;
      chunks.add(bytes.sublist(offset, end));
    }
    final file = PlatformFile(
      name: 'MoeBackup.json',
      size: bytes.length,
      readStream: Stream<List<int>>.fromIterable(chunks),
    );

    expect(await readPickedFileContent(file), content);
  });
}
