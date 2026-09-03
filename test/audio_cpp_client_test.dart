import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/audio_cpp_client.dart';

void main() {
  test('sends an inline WAV voice reference and returns generated audio',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? requestBody;
    String? accept;
    final outputWav = Uint8List.fromList([
      ...ascii.encode('RIFF'),
      1,
      2,
      3,
      4,
      ...ascii.encode('WAVE'),
    ]);

    final serverTask = () async {
      final request = await server.first;
      accept = request.headers.value(HttpHeaders.acceptHeader);
      requestBody = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('audio', 'wav')
        ..add(outputWav);
      await request.response.close();
    }();

    try {
      final referenceWav = Uint8List.fromList([
        ...ascii.encode('RIFF'),
        0,
        0,
        0,
        0,
        ...ascii.encode('WAVE'),
      ]);
      final client = AudioCppClient(
        baseUrl: 'http://${server.address.address}:${server.port}/',
      );
      final result = await client.createVoiceClone(
        model: 'qwen3-tts',
        text: '你好，老师。',
        referenceWav: referenceWav,
        referenceText: '参考文本。',
        language: 'Chinese',
      );
      await serverTask;

      expect(result, outputWav);
      expect(accept, 'audio/wav');
      expect(requestBody, containsPair('model', 'qwen3-tts'));
      expect(requestBody, containsPair('input', '你好，老师。'));
      expect(requestBody, containsPair('reference_text', '参考文本。'));
      expect(requestBody, containsPair('language', 'Chinese'));
      expect(requestBody!.containsKey('options'), isFalse);
      expect(
        requestBody!['voice_ref'],
        {
          'type': 'base64',
          'data': base64Encode(referenceWav),
        },
      );
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });

  test('uses Qwen3 x-vector-only mode when a card has no transcript', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? requestBody;
    final serverTask = () async {
      final request = await server.first;
      requestBody = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('audio', 'wav')
        ..add(ascii.encode('RIFF....WAVE'));
      await request.response.close();
    }();

    try {
      await AudioCppClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ).createVoiceClone(
        model: 'qwen3-tts',
        text: '你好',
        referenceWav: Uint8List.fromList([1, 2, 3]),
        language: 'Chinese',
      );
      await serverTask;

      expect(requestBody!.containsKey('reference_text'), isFalse);
      expect(requestBody!['options'], {'x_vector_only_mode': true});
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });

  test('checks health and lists configured model ids', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverTask = () async {
      await for (final request in server) {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/health') {
          request.response.write('{"status":"ok"}');
        } else if (request.uri.path == '/v1/models') {
          request.response.write(jsonEncode({
            'object': 'list',
            'data': [
              {'id': 'qwen3-tts', 'object': 'model'},
              {'id': 'pocket-tts', 'object': 'model'},
            ],
          }));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      }
    }();

    try {
      final client = AudioCppClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      await client.checkHealth();
      expect(await client.listModels(), ['qwen3-tts', 'pocket-tts']);
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });

  test('surfaces audio.cpp JSON errors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverTask = () async {
      final request = await server.first;
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': {
            'message': 'unknown model id: missing',
            'type': 'invalid_request_error',
          },
        }));
      await request.response.close();
    }();

    try {
      final client = AudioCppClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      await expectLater(
        client.createVoiceClone(
          model: 'missing',
          text: 'test',
          referenceWav: Uint8List.fromList([1]),
        ),
        throwsA(
          isA<AudioCppException>().having(
            (error) => error.message,
            'message',
            contains('unknown model id'),
          ),
        ),
      );
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });
}
