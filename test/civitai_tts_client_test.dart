import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/civitai_client.dart';

void main() {
  test('submits and polls a Civitai voice clone workflow', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? submittedBody;
    String? authorization;

    final serverTask = () async {
      await for (final request in server) {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST') {
          authorization =
              request.headers.value(HttpHeaders.authorizationHeader);
          submittedBody = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          request.response.write(jsonEncode({
            'id': 'wf_test',
            'status': 'processing',
            'steps': [
              {
                'output': {
                  'audioBlob': {
                    'available': false,
                    'url': 'https://example.com/not-ready.ogg',
                  },
                },
              },
            ],
          }));
        } else {
          request.response.write(jsonEncode({
            'id': 'wf_test',
            'status': 'succeeded',
            'steps': [
              {
                'output': {
                  'audioBlob': {
                    'type': 'audio',
                    'available': true,
                    'url': 'https://example.com/result.ogg',
                  },
                },
              },
            ],
          }));
        }
        await request.response.close();
      }
    }();

    try {
      final client = CivitaiClient(
        apiToken: 'test-token',
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      final result = await client.textToSpeech.createVoiceClone(
        text: '你好，老师。',
        refAudioUrl: 'https://example.com/reference.wav',
        refText: '老师，早上好。',
        language: 'Chinese',
        timeout: const Duration(seconds: 10),
      );

      expect(result, 'https://example.com/result.ogg');
      expect(authorization, 'Bearer test-token');
      final steps = submittedBody!['steps'] as List<dynamic>;
      final step = steps.single as Map<String, dynamic>;
      final input = step['input'] as Map<String, dynamic>;
      expect(step, containsPair('\$type', 'textToSpeech'));
      expect(input, containsPair('engine', 'custom'));
      expect(input, containsPair('refText', '老师，早上好。'));
      expect(input, containsPair('xVectorOnlyMode', false));
      expect(input, containsPair('language', 'Chinese'));
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });

  test('uses x-vector-only mode when an old card has no transcript', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? submittedBody;

    final serverTask = () async {
      await for (final request in server) {
        submittedBody = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'id': 'wf_inline',
          'status': 'succeeded',
          'steps': [
            {
              'output': {
                'audioBlob': {
                  'available': true,
                  'url': 'https://example.com/inline.ogg',
                },
              },
            },
          ],
        }));
        await request.response.close();
      }
    }();

    try {
      final client = CivitaiClient(
        apiToken: 'test-token',
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      final result = await client.textToSpeech.createVoiceClone(
        text: 'Hello.',
        refAudioUrl: 'https://example.com/reference.wav',
      );

      expect(result, 'https://example.com/inline.ogg');
      final steps = submittedBody!['steps'] as List<dynamic>;
      final step = steps.single as Map<String, dynamic>;
      final input = step['input'] as Map<String, dynamic>;
      expect(input, isNot(contains('refText')));
      expect(input, containsPair('xVectorOnlyMode', true));
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });
}
