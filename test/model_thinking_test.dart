import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/model_thinking.dart';
import 'package:moetalk/app_version.dart';
import 'package:moetalk/openai.dart';
import 'package:moetalk/storage.dart';
import 'package:moetalk/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

Config config({
  String url = 'https://example.com/v1',
  ThinkingMode mode = ThinkingMode.automatic,
  String? effort,
  ThinkingApi api = ThinkingApi.automatic,
}) =>
    Config(
      name: 'test',
      baseUrl: url,
      apiKey: 'test-key',
      model: 'test-model',
      thinkingMode: mode,
      thinkingEffort: effort,
      thinkingApi: api,
    );

void main() {
  test('defaults send no thinking overrides to any provider', () {
    for (final api in ThinkingApi.values) {
      expect(thinkingParameters(config(api: api)), isEmpty);
    }
  });

  test('OpenAI and Gemini use effort; disabling takes precedence', () {
    expect(thinkingParameters(config(mode: ThinkingMode.enabled)),
        {'reasoning_effort': 'medium'});
    expect(thinkingParameters(config(effort: 'high')),
        {'reasoning_effort': 'high'});
    expect(
        thinkingParameters(config(mode: ThinkingMode.disabled, effort: 'high')),
        {'reasoning_effort': 'none'});
  });

  test('DeepSeek auto detection and explicit proxy format', () {
    for (final cfg in [
      config(url: 'https://api.deepseek.com/v1', effort: 'low'),
      config(api: ThinkingApi.deepseek, effort: 'low'),
    ]) {
      expect(thinkingParameters(cfg), {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'low',
      });
    }
    expect(
        thinkingParameters(config(
            api: ThinkingApi.deepseek,
            mode: ThinkingMode.disabled,
            effort: 'high')),
        {
          'thinking': {'type': 'disabled'}
        });
  });

  test('OpenRouter sends unified reasoning, not a top-level effort', () {
    expect(
        thinkingParameters(
            config(url: 'https://openrouter.ai/api/v1', effort: 'high')),
        {
          'reasoning': {'enabled': true, 'effort': 'high'},
        });
    expect(
        thinkingParameters(config(
            api: ThinkingApi.openrouter,
            mode: ThinkingMode.disabled,
            effort: 'high')),
        {
          'reasoning': {'enabled': false},
        });
  });

  test('llama.cpp sets the chat template toggle and effort', () {
    expect(
        thinkingParameters(config(
            api: ThinkingApi.llamaCpp,
            mode: ThinkingMode.enabled,
            effort: 'low')),
        {
          'chat_template_kwargs': {'enable_thinking': true},
          'reasoning_effort': 'low',
        });
    expect(
        thinkingParameters(config(
            api: ThinkingApi.llamaCpp,
            mode: ThinkingMode.disabled,
            effort: 'high')),
        {
          'chat_template_kwargs': {'enable_thinking': false},
          'reasoning_effort': 'none',
        });
  });

  test('Gemini compatibility endpoint repairs old presets only', () {
    expect(
        completionEndpoint(
                ' https://generativelanguage.googleapis.com/v1beta/// ')
            .toString(),
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
    expect(
        completionEndpoint(
                'https://generativelanguage.googleapis.com/v1beta/openai/')
            .toString(),
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
    expect(completionEndpoint('https://example.com/v1/').toString(),
        'https://example.com/v1/chat/completions');
  });

  test('OpenAI reasoning payload uses the token limit accepted by its API', () {
    final cfg = config(url: 'https://api.openai.com/v1', effort: 'high')
      ..model = 'gpt-5'
      ..temperature = '0.5'
      ..presencePenalty = '1'
      ..frequencyPenalty = '1'
      ..maxTokens = '8192';
    final body = completionPayload(cfg, const [
      ['user', 'Hello'],
    ]);
    expect(body['reasoning_effort'], 'high');
    expect(body['max_completion_tokens'], 8192);
    expect(body.containsKey('max_tokens'), isFalse);
    expect(body.containsKey('temperature'), isFalse);
    expect(body.containsKey('presence_penalty'), isFalse);
    expect(body.containsKey('frequency_penalty'), isFalse);
    // Existing compatible services retain the conventional sampling fields.
    cfg.baseUrl = 'https://example.com/v1';
    final compatible = completionPayload(cfg, const []);
    expect(compatible['max_tokens'], 8192);
    expect(compatible['temperature'], 0.5);
  });

  test('thinking survives saving and selecting the drawing prompt model',
      () async {
    SharedPreferences.setMockInitialValues({});
    final original = config(
        mode: ThinkingMode.enabled, effort: 'high', api: ThinkingApi.deepseek);
    await setApiConfig(original);
    await setCurrentApiConfig(original.name);
    await setAidrawApiConfig(original.name);
    for (final stored in [
      (await getApiConfigs()).single,
      (await getAidrawApiConfig())!,
    ]) {
      expect(stored.thinkingMode, ThinkingMode.enabled);
      expect(stored.thinkingEffort, 'high');
      expect(stored.thinkingApi, ThinkingApi.deepseek);
    }
  });

  test('legacy three/seven-field and future configs preserve defaults',
      () async {
    SharedPreferences.setMockInitialValues({
      'current_api': 'api_old',
      'api_old': ['https://example.com/v1', 'key', 'model'],
      'api_seven': ['url', 'key', 'model', '0.5', '', '', '8192'],
      'api_future': [
        'url',
        'key',
        'model',
        '',
        '',
        '',
        '',
        'unknown',
        'invalid',
        'unknown'
      ],
      'api_broken': ['url'],
      'aidraw_api': 'api_seven',
    });
    final configs = await getApiConfigs();
    expect(configs.map((cfg) => cfg.name),
        containsAll(['old', 'seven', 'future']));
    expect(configs.length, 3);
    expect(configs.first.name, 'old');
    for (final cfg in configs) {
      expect(cfg.thinkingMode, ThinkingMode.automatic);
      expect(cfg.thinkingEffort, isNull);
      expect(cfg.thinkingApi, ThinkingApi.automatic);
    }
    final drawing = (await getAidrawApiConfig())!;
    expect(drawing.temperature, '0.5');
    expect(drawing.maxTokens, '8192');
  });

  test('default display version follows the package version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $appVersion'));
  });
}
