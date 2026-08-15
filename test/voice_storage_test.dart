import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/storage.dart';
import 'package:moetalk/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('pads old character records and keeps transcript optional', () async {
    SharedPreferences.setMockInitialValues({
      'name': 'Old Character',
      'student_123_Old Character': <String>[
        'Old Character',
        'avatar',
        'hello',
        'description',
        '123',
        'draw prompt',
        'https://example.com/reference.wav',
        'lora',
      ],
    });

    final students = await getStudents();
    expect(students.single, hasLength(9));
    expect(students.single[8], isEmpty);
    expect(await getVitsPromptText(), isEmpty);
  });

  test('stores the Civitai TTS token and language', () async {
    SharedPreferences.setMockInitialValues({
      'civitai_api_token': 'drawing-token',
    });

    final fallback = await getVitsConfig();
    expect(fallback.apiToken, 'drawing-token');
    expect(fallback.language, 'Auto');

    await setVitsConfig(VitsConfig(
      apiToken: 'voice-token',
      language: 'Chinese',
    ));
    final stored = await getVitsConfig();
    expect(stored.apiToken, 'voice-token');
    expect(stored.language, 'Chinese');
  });
}
