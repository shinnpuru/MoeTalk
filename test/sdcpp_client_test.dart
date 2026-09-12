import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/sdcpp_client.dart';

Future<HttpServer> _serve(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } finally {
      await request.response.close();
    }
  });
  return server;
}

String _baseUrl(HttpServer server) =>
    'http://${server.address.address}:${server.port}';

void main() {
  group('resolveSdCppSampler', () {
    test('maps A1111 sampler names onto sd.cpp sample methods', () {
      expect(resolveSdCppSampler('EulerA').sampleMethod, 'euler_a');
      expect(resolveSdCppSampler('Euler a').sampleMethod, 'euler_a');
      expect(resolveSdCppSampler('euler_a').sampleMethod, 'euler_a');
      expect(resolveSdCppSampler('DPM++ 2M').sampleMethod, 'dpm++2m');
      expect(resolveSdCppSampler('DPM++ 2M SDE').sampleMethod, 'dpm++2m_sde');
      expect(resolveSdCppSampler('DPM++ 2S a').sampleMethod, 'dpm++2s_a');
      expect(resolveSdCppSampler('DDIM').sampleMethod, 'ddim_trailing');
      expect(resolveSdCppSampler('LCM').sampleMethod, 'lcm');
      expect(resolveSdCppSampler('automatic').sampleMethod, isNull);
      expect(resolveSdCppSampler('').sampleMethod, isNull);
    });

    test('splits the sampler from a trailing scheduler name', () {
      final selection = resolveSdCppSampler('DPM++ 2M Karras');
      expect(selection.sampleMethod, 'dpm++2m');
      expect(selection.scheduler, 'karras');
      expect(selection.unsupportedSampler, isNull);

      final schedulerOnly = resolveSdCppSampler('Karras');
      expect(schedulerOnly.sampleMethod, isNull);
      expect(schedulerOnly.scheduler, 'karras');
    });

    test('reports samplers sd.cpp cannot run instead of guessing', () {
      final selection = resolveSdCppSampler('UniPC');
      expect(selection.sampleMethod, isNull);
      expect(selection.unsupportedSampler, 'UniPC');
    });

    test('validates against the capabilities the server reported', () {
      final selection = resolveSdCppSampler(
        'DPM++ 3M SDE',
        availableMethods: const ['euler', 'euler_a', 'dpm++2m'],
        availableSchedulers: const ['karras'],
      );
      expect(selection.sampleMethod, isNull);
      expect(selection.unsupportedSampler, isNotNull);

      final unsupportedScheduler = resolveSdCppSampler(
        'Euler a Karras',
        availableMethods: const ['euler_a'],
        availableSchedulers: const ['normal'],
      );
      expect(unsupportedScheduler.sampleMethod, 'euler_a');
      expect(unsupportedScheduler.scheduler, isNull);
      expect(unsupportedScheduler.ignoredScheduler, 'karras');
    });
  });

  group('resolveSdCppLoras', () {
    const loras = [
      SdCppLora(name: 'detail', path: 'styles/detail.safetensors'),
      SdCppLora(name: 'lineart', path: 'lineart.safetensors'),
    ];

    test('resolves names to the paths the server accepts', () {
      final resolved = resolveSdCppLoras(
        '<detail:0.8>,<lineart:1.2>',
        availableLoras: loras,
      );
      expect(resolved, hasLength(2));
      expect(resolved.first.path, 'styles/detail.safetensors');
      expect(resolved.first.multiplier, 0.8);
      expect(resolved.last.path, 'lineart.safetensors');
      expect(resolved.last.multiplier, 1.2);
    });

    test('matches by file name and drops unknown LoRAs', () {
      final skipped = <String>[];
      final resolved = resolveSdCppLoras(
        '<lineart.safetensors:1.0>,<urn:air:lora:civitai:1@2:0.5>',
        availableLoras: loras,
        onSkip: skipped.add,
      );
      expect(resolved, hasLength(1));
      expect(resolved.single.path, 'lineart.safetensors');
      expect(skipped, ['urn:air:lora:civitai:1@2']);
    });

    test('accepts a bare LoRA name', () {
      final resolved = resolveSdCppLoras('detail', availableLoras: loras);
      expect(resolved.single.path, 'styles/detail.safetensors');
      expect(resolved.single.multiplier, 1.0);
    });
  });

  group('SdCppClient', () {
    test('reads capabilities', () async {
      final server = await _serve((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'model': {
            'name': 'waiIllustriousSDXL_v160.safetensors',
            'path': 'waiIllustriousSDXL_v160.safetensors',
            'stem': 'waiIllustriousSDXL_v160',
          },
          'samplers': ['euler', 'euler_a', 'dpm++2m'],
          'schedulers': ['normal', 'karras'],
          'loras': [
            {'name': 'detail', 'path': 'styles/detail.safetensors'},
          ],
          'supported_modes': ['img_gen'],
          'output_formats': ['png', 'jpeg', 'webp'],
          'limits': {'min_width': 64, 'max_width': 4096},
        }));
      });

      try {
        final capabilities =
            await SdCppClient(baseUrl: _baseUrl(server)).fetchCapabilities();
        expect(capabilities.modelStem, 'waiIllustriousSDXL_v160');
        expect(capabilities.displayModel, 'waiIllustriousSDXL_v160');
        expect(capabilities.samplers, contains('euler_a'));
        expect(capabilities.schedulers, contains('karras'));
        expect(capabilities.loras.single.path, 'styles/detail.safetensors');
        expect(capabilities.outputFormats, contains('webp'));
        expect(capabilities.maxWidth, 4096);
        expect(capabilities.supportsImageGeneration, isTrue);
      } finally {
        await server.close(force: true);
      }
    });

    test('submits the app configuration and decodes the generated image',
        () async {
      final imageBytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
      Map<String, dynamic>? submitted;
      final paths = <String>[];
      var polls = 0;

      final server = await _serve((request) async {
        paths.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/sdcpp/v1/img_gen') {
          submitted = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.accepted;
          request.response.write(jsonEncode({
            'id': 'job_test_1',
            'status': 'queued',
            'kind': 'img_gen',
          }));
        } else if (request.uri.path == '/sdcpp/v1/jobs/job_test_1') {
          polls++;
          if (polls == 1) {
            request.response.write(jsonEncode({
              'id': 'job_test_1',
              'status': 'generating',
              'queue_position': 2,
            }));
          } else {
            request.response.write(jsonEncode({
              'id': 'job_test_1',
              'status': 'completed',
              'queue_position': 0,
              'result': {
                'output_format': 'webp',
                'images': [
                  {'b64_json': base64Encode(imageBytes)},
                ],
              },
            }));
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'error': 'job not found'}));
        }
      });

      try {
        final client = SdCppClient(
          baseUrl: _baseUrl(server),
          pollInterval: const Duration(milliseconds: 1),
        );
        final jobId = await client.submitImage(const SdCppImageRequest(
          prompt: '1girl, cherry blossoms',
          negativePrompt: 'nsfw',
          width: 832,
          height: 1216,
          steps: 28,
          cfgScale: 5.5,
          seed: -1,
          clipSkip: 2,
          sampleMethod: 'dpm++2m',
          scheduler: 'karras',
          loras: [SdCppLoraRef(path: 'styles/detail.safetensors', multiplier: 0.8)],
        ));
        expect(jobId, 'job_test_1');

        final statuses = <String>[];
        final job = await client.waitForJob(
          jobId,
          onUpdate: (job) => statuses.add(job.status),
        );

        expect(statuses, ['generating', 'completed']);
        expect(job.images.single.bytes, imageBytes);
        expect(job.images.single.extension, 'webp');
        expect(job.outputFormat, 'webp');

        expect(submitted, containsPair('prompt', '1girl, cherry blossoms'));
        expect(submitted, containsPair('negative_prompt', 'nsfw'));
        expect(submitted, containsPair('width', 832));
        expect(submitted, containsPair('height', 1216));
        expect(submitted, containsPair('batch_count', 1));
        expect(submitted, containsPair('seed', -1));
        expect(submitted, containsPair('clip_skip', 2));
        expect(submitted!['sample_params'], containsPair('sample_steps', 28));
        expect(
          submitted!['sample_params'],
          containsPair('sample_method', 'dpm++2m'),
        );
        expect(submitted!['sample_params'], containsPair('scheduler', 'karras'));
        expect(
          submitted!['sample_params']['guidance'],
          containsPair('txt_cfg', 5.5),
        );
        expect(submitted!['lora'], [
          {
            'path': 'styles/detail.safetensors',
            'multiplier': 0.8,
            'is_high_noise': false,
          },
        ]);
        expect(paths.first, 'POST /sdcpp/v1/img_gen');
      } finally {
        await server.close(force: true);
      }
    });

    test('surfaces job failures reported by the server', () async {
      final server = await _serve((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'id': 'job_test_2',
          'status': 'failed',
          'error': {'message': 'failed to allocate compute buffer'},
        }));
      });

      try {
        final client = SdCppClient(
          baseUrl: _baseUrl(server),
          pollInterval: const Duration(milliseconds: 1),
        );
        await expectLater(
          client.waitForJob('job_test_2'),
          throwsA(
            isA<SdCppException>().having(
              (error) => error.message,
              'message',
              contains('failed to allocate compute buffer'),
            ),
          ),
        );
      } finally {
        await server.close(force: true);
      }
    });

    test('surfaces HTTP errors raised when submitting', () async {
      final server = await _serve((request) async {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.badRequest
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'invalid generation parameters'}));
      });

      try {
        final client = SdCppClient(baseUrl: _baseUrl(server));
        await expectLater(
          client.submitImage(const SdCppImageRequest(prompt: 'test')),
          throwsA(
            isA<SdCppException>()
                .having((error) => error.statusCode, 'statusCode', 400)
                .having(
                  (error) => error.message,
                  'message',
                  contains('invalid generation parameters'),
                ),
          ),
        );
      } finally {
        await server.close(force: true);
      }
    });

    test('cancels the running job when the caller gives up', () async {
      final paths = <String>[];
      final server = await _serve((request) async {
        paths.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST') {
          request.response.write(jsonEncode({'status': 'cancelled'}));
          return;
        }
        request.response.write(jsonEncode({
          'id': 'job_test_3',
          'status': 'generating',
        }));
      });

      try {
        final client = SdCppClient(
          baseUrl: _baseUrl(server),
          pollInterval: const Duration(milliseconds: 1),
        );
        await expectLater(
          client.waitForJob('job_test_3', isCancelled: () => true),
          throwsA(isA<SdCppCancelledException>()),
        );
        expect(paths, contains('POST /sdcpp/v1/jobs/job_test_3/cancel'));
      } finally {
        await server.close(force: true);
      }
    });

    test('normalises the configured base URL', () {
      final client = SdCppClient(baseUrl: '127.0.0.1:1234/');
      expect(client.endpoint('/sdcpp/v1/capabilities').toString(),
          'http://127.0.0.1:1234/sdcpp/v1/capabilities');
      expect(
        () => const SdCppClient(baseUrl: '   ').endpoint('/x'),
        throwsA(isA<SdCppException>()),
      );
    });
  });
}
