import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
