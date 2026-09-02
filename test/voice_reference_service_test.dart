import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/civitai_client.dart';
import 'package:moetalk/voice_reference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uploads WAV bytes with the Civitai blob API', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    String? authorization;
    ContentType? contentType;
    List<int>? body;

    final serverTask = () async {
      final request = await server.first;
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      contentType = request.headers.contentType;
      body = await request.fold<List<int>>(<int>[], (all, chunk) {
        all.addAll(chunk);
        return all;
      });
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'id': 'voice-reference.wav',
          'available': true,
          'url': 'https://example.com/voice-reference.wav',
          'urlExpiresAt': '2030-01-01T00:00:00Z',
        }));
      await request.response.close();
      received.complete();
    }();

    try {
      final client = CivitaiClient(
        apiToken: 'test-token',
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      final blob = await client.blobs.uploadWav(Uint8List.fromList([1, 2, 3]));
      await received.future;

      expect(blob.id, 'voice-reference.wav');
      expect(
        blob.air,
        'urn:air:other:other:orchestrator:blob@voice-reference.wav',
      );
      expect(authorization, 'Bearer test-token');
      expect(contentType?.mimeType, 'audio/wav');
      expect(body, [1, 2, 3]);
    } finally {
      await server.close(force: true);
      await serverTask;
    }
  });

  test('persists and reuses a blob AIR for the same source', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var downloads = 0;
    var normalizations = 0;
    var uploads = 0;

    VoiceReferenceService service() => VoiceReferenceService(
          civitaiClient: CivitaiClient(apiToken: 'same-account'),
          preferences: prefs,
          downloader: (_) async {
            downloads++;
            return Uint8List.fromList([1, 2, 3]);
          },
          normalizer: (bytes) async {
            normalizations++;
            return Uint8List.fromList([4, 5, 6]);
          },
          uploader: (_) async {
            uploads++;
            return CivitaiBlob(
              id: 'cached.wav',
              available: true,
              urlExpiresAt: DateTime.now().add(const Duration(days: 30)),
            );
          },
        );

    final first = await service().resolve('https://example.com/reference.ogg');
    final second = await service().resolve('https://example.com/reference.ogg');

    expect(first, second);
    expect(first, endsWith('@cached.wav'));
    expect(downloads, 1);
    expect(normalizations, 1);
    expect(uploads, 1);
  });

  test('reuses one blob when different URLs contain the same WAV', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final wav = Uint8List.fromList([
      ...ascii.encode('RIFF'),
      0,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);
    var uploads = 0;
    final service = VoiceReferenceService(
      civitaiClient: CivitaiClient(apiToken: 'content-account'),
      preferences: prefs,
      downloader: (_) async => wav,
      uploader: (_) async {
        uploads++;
        return const CivitaiBlob(id: 'shared.wav', available: true);
      },
    );

    final first = await service.resolve('https://one.example/reference.wav');
    final second = await service.resolve('https://two.example/copy.wav');

    expect(first, second);
    expect(uploads, 1);
  });

  test('deduplicates concurrent resolutions for the same source', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final uploadStarted = Completer<void>();
    final finishUpload = Completer<CivitaiBlob>();
    var uploads = 0;
    final service = VoiceReferenceService(
      civitaiClient: CivitaiClient(apiToken: 'concurrent-account'),
      preferences: prefs,
      downloader: (_) async => Uint8List.fromList([1]),
      normalizer: (bytes) async => Uint8List.fromList([2]),
      uploader: (_) {
        uploads++;
        uploadStarted.complete();
        return finishUpload.future;
      },
    );

    final first = service.resolve('https://example.com/same.ogg');
    final second = service.resolve('https://example.com/same.ogg');
    await uploadStarted.future;
    finishUpload.complete(const CivitaiBlob(
      id: 'one-upload.wav',
      available: true,
    ));

    expect(await Future.wait([first, second]),
        everyElement(endsWith('@one-upload.wav')));
    expect(uploads, 1);
  });

  test('refreshes an expired cached blob without downloading again', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var downloads = 0;
    var uploads = 0;
    var refreshes = 0;

    VoiceReferenceService service() => VoiceReferenceService(
          civitaiClient: CivitaiClient(apiToken: 'refresh-account'),
          preferences: prefs,
          downloader: (_) async {
            downloads++;
            return Uint8List.fromList([1]);
          },
          normalizer: (bytes) async => Uint8List.fromList([2]),
          uploader: (_) async {
            uploads++;
            return CivitaiBlob(
              id: 'refresh-me.wav',
              available: true,
              urlExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
            );
          },
          refresher: (blobId) async {
            refreshes++;
            expect(blobId, 'refresh-me.wav');
            return CivitaiBlob(
              id: blobId,
              available: true,
              urlExpiresAt: DateTime.now().add(const Duration(days: 30)),
            );
          },
        );

    await service().resolve('https://example.com/expiring.ogg');
    await service().resolve('https://example.com/expiring.ogg');

    expect(downloads, 1);
    expect(uploads, 1);
    expect(refreshes, 1);
  });

  test('does not upload a downloaded unsupported reference', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var uploads = 0;
    final service = VoiceReferenceService(
      civitaiClient: CivitaiClient(apiToken: 'wav-only-account'),
      preferences: prefs,
      downloader: (_) async => Uint8List.fromList(ascii.encode('OggS')),
      uploader: (_) async {
        uploads++;
        return const CivitaiBlob(id: 'unexpected.wav', available: true);
      },
    );

    await expectLater(
      service.resolve('https://example.com/reference.ogg'),
      throwsA(isA<FormatException>()),
    );
    expect(uploads, 0);
  });
}
