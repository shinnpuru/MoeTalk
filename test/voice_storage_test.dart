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
    expect(stored.backend, TtsBackend.civitai);
    expect(stored.audioCppBaseUrl, 'http://127.0.0.1:8080');
  });

  test('stores audio.cpp connection settings', () async {
    SharedPreferences.setMockInitialValues({});

    await setVitsConfig(VitsConfig(
      backend: TtsBackend.audioCpp,
      language: 'Chinese',
      audioCppBaseUrl: 'http://192.168.1.20:8080',
      audioCppModel: 'qwen3-tts',
    ));

    final stored = await getVitsConfig();
    expect(stored.backend, TtsBackend.audioCpp);
    expect(stored.language, 'Chinese');
    expect(stored.audioCppBaseUrl, 'http://192.168.1.20:8080');
    expect(stored.audioCppModel, 'qwen3-tts');
  });

  test('updates voice fields on the active character card', () async {
    SharedPreferences.setMockInitialValues({
      'name': 'Shared name',
      'active_student_timestamp': 'second',
      'student_first_Shared name': <String>[
        'Shared name',
        'avatar 1',
        'hello 1',
        'description 1',
        'first',
        'draw 1',
        'old-1.wav',
        'lora 1',
        'old transcript 1',
      ],
      'student_second_Shared name': <String>[
        'Shared name',
        'avatar 2',
        'hello 2',
        'description 2',
        'second',
        'draw 2',
        'old-2.wav',
        'lora 2',
        'old transcript 2',
      ],
    });

    await updateActiveStudentVoice('new.mp3', 'new transcript');

    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getStringList('student_first_Shared name')!;
    final second = prefs.getStringList('student_second_Shared name')!;
    expect(first[6], 'old-1.wav');
    expect(first[8], 'old transcript 1');
    expect(second[6], 'new.mp3');
    expect(second[8], 'new transcript');
    expect(await getVitsPrompt(), 'new.mp3');
    expect(await getVitsPromptText(), 'new transcript');
  });

  test('updates an existing character by name before a new switch', () async {
    SharedPreferences.setMockInitialValues({
      'name': 'Legacy character',
      'student_123_Legacy character': <String>[
        'Legacy character',
        'avatar',
        'hello',
        'description',
        '123',
        'draw',
        'old.wav',
        'lora',
        'old transcript',
      ],
    });

    await updateActiveStudentVoice('updated.wav', 'updated transcript');

    expect(await getVitsPrompt(), 'updated.wav');
    expect(await getVitsPromptText(), 'updated transcript');
  });
}
