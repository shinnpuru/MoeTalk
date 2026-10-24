import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/openai.dart';
import 'package:moetalk/utils.dart';

void main() {
  Future<String> readStream(List<String> frames) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Future<void>>[];
    final subscription = server.listen((request) {
      requests.add(() async {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType =
            ContentType('text', 'event-stream', charset: 'utf-8');
        request.response.bufferOutput = false;
        try {
          for (final frame in frames) {
            request.response.write(frame);
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await request.response.close();
        } on SocketException {
          // An error frame makes the client close the response intentionally.
        } on HttpException {
          // The client may have already closed before the next fixture frame.
        }
      }());
    });
    try {
      return await collectCompletion(
        Config(
          name: 'SSE fixture',
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          apiKey: '',
          model: 'fixture',
        ),
        const [
          ['user', 'Reply with OK.'],
        ],
        timeout: const Duration(seconds: 5),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      await Future.wait(requests);
    }
  }

  String chunk(String text) => 'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': text}
              }
            ]
          })}\n\n';

  for (final comment in [': keep-alive', ': OPENROUTER PROCESSING']) {
    test('ignores $comment before and between content events', () async {
      expect(
        await readStream([
          '$comment\n\n',
          chunk('O'),
          '$comment\n\n',
          chunk('K'),
          'data: [DONE]\n\n',
        ]),
        'OK',
      );
    });
  }

  test('ignores blank, whitespace and event-only SSE frames', () async {
    expect(
      await readStream([
        '\n\n',
        'data:\n\n',
        'data:   \n\n',
        'event: ping\n\n',
        chunk('你好'),
        'data:   [DONE]  \n\n',
      ]),
      '你好',
    );
  });

  test('ignores reasoning-only and usage-only chunks', () async {
    expect(
      await readStream([
        'data: {"choices":[{"delta":{"role":"assistant","content":null,"reasoning_content":"thinking"}}]}\n\n',
        chunk('OK'),
        'data: {"choices":[],"usage":{"completion_tokens":1}}\n\n',
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n',
        'data: [DONE]\n\n',
      ]),
      'OK',
    );
  });

  test('does not swallow a provider error after a heartbeat', () async {
    await expectLater(
      readStream([
        ': OPENROUTER PROCESSING\n\n',
        'data: {"error":{"message":"Provider unavailable"},"choices":[]}\n\n',
        'data: [DONE]\n\n',
      ]),
      throwsA('Provider unavailable'),
    );
  });

  test('does not mistake malformed text containing DONE for the terminator',
      () async {
    await expectLater(
      readStream([chunk('OK'), 'data: BROKEN DONE payload\n\n']),
      throwsA(startsWith('Unexpected response:')),
    );
  });
}
