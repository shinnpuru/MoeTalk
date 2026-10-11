import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/openai.dart';
import 'package:moetalk/utils.dart';

void main() {
  for (final scenario in [
    'success',
    'unauthorized',
    'empty',
    'error',
    'timeout'
  ]) {
    test('language model connection test handles $scenario', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/v1/chat/completions');
        expect(request.headers.value('authorization'), 'Bearer test-key');
        final payload = jsonDecode(await utf8.decoder.bind(request).join());
        expect(payload['model'], 'test-model');
        expect(payload['stream'], true);
        expect(payload['temperature'], 0.5);
        expect(payload['max_tokens'], 64);
        expect(payload['messages'], [
          {'role': 'user', 'content': 'Reply with OK.'}
        ]);
        if (scenario == 'timeout') return;
        if (scenario == 'unauthorized') {
          request.response.statusCode = 401;
          request.response.write('{"error":{"message":"Invalid API key"}}');
        } else {
          request.response.headers.contentType =
              ContentType('text', 'event-stream', charset: 'utf-8');
          if (scenario == 'success') {
            request.response
                .write('data: {"choices":[{"delta":{"content":"OK"}}]}\n\n');
          } else if (scenario == 'error') {
            request.response
                .write('data: {"error":{"message":"Model unavailable"}}\n\n');
          }
          request.response.write('data: [DONE]\n\n');
        }
        await request.response.close();
      });

      final config = Config(
        name: 'test',
        baseUrl: 'http://${server.address.address}:${server.port}/v1/',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: '0.5',
        maxTokens: '64',
      );
      final operation = testModelConnection(config,
          timeout: scenario == 'timeout'
              ? const Duration(milliseconds: 200)
              : const Duration(seconds: 5));
      switch (scenario) {
        case 'success':
          await operation;
        case 'empty':
          await expectLater(operation, throwsA(isA<FormatException>()));
        case 'error':
          await expectLater(operation, throwsA('Model unavailable'));
        case 'timeout':
          await expectLater(operation, throwsA(isA<TimeoutException>()));
        default:
          await expectLater(operation, throwsA(anything));
      }
    });
  }
}
