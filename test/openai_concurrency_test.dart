import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/openai.dart' as openai;
import 'package:moetalk/utils.dart';

void main() {
  test('parallel completions keep their SSE streams isolated', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Future<void>>[];
    final subscription = server.listen((request) {
      requests.add(_serveCompletion(request));
    });

    addTearDown(() async {
      await subscription.cancel();
      await Future.wait(requests);
      await server.close(force: true);
    });

    final config = Config(
      name: 'test',
      baseUrl: 'http://${server.address.address}:${server.port}',
      apiKey: 'test-key',
      model: 'test-model',
    );

    final first = _collectCompletion(config, 'first');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final second = _collectCompletion(config, 'second');

    expect(
      await Future.wait([first, second]),
      ['first-a first-b', 'second-a second-b'],
    );
  });
}

Future<String> _collectCompletion(Config config, String prompt) {
  return openai.collectCompletion(config, [
    ['user', prompt],
  ]).timeout(const Duration(seconds: 3));
}

Future<void> _serveCompletion(HttpRequest request) async {
  final payload = jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
  final messages = payload['messages'] as List<dynamic>;
  final lastMessage = messages.last as Map<String, dynamic>;
  final prompt = lastMessage['content'] as String;

  request.response.headers.contentType = ContentType(
    'text',
    'event-stream',
    charset: 'utf-8',
  );
  request.response.bufferOutput = false;

  if (prompt == 'second') {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  await _sendChunk(request.response, '$prompt-a ');
  await Future<void>.delayed(
    Duration(milliseconds: prompt == 'first' ? 80 : 20),
  );
  await _sendChunk(request.response, '$prompt-b');
  request.response.write('data: [DONE]\n\n');
  await request.response.close();
}

Future<void> _sendChunk(HttpResponse response, String content) async {
  final data = jsonEncode({
    'choices': [
      {
        'delta': {'content': content},
      },
    ],
  });
  response.write('data: $data\n\n');
  await response.flush();
}
