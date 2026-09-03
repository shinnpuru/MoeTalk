import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'civitai_client.dart';
import 'voice_audio_normalizer.dart';

typedef VoiceAudioDownloader = Future<Uint8List> Function(Uri uri);
typedef VoiceAudioNormalizer = Future<Uint8List> Function(Uint8List bytes);
typedef VoiceBlobUploader = Future<CivitaiBlob> Function(Uint8List wavBytes);
typedef VoiceBlobRefresher = Future<CivitaiBlob> Function(String blobId);

class VoiceReferenceLoader {
  static const _maximumDownloadBytes = 16 * 1024 * 1024;

  final VoiceAudioDownloader? downloader;
  final VoiceAudioNormalizer normalizer;

  const VoiceReferenceLoader({
    this.downloader,
    this.normalizer = prepareVoiceReferenceWav,
  });

  Future<Uint8List> loadWav(String source) async {
    final trimmedSource = source.trim();
    if (trimmedSource.isEmpty) {
      throw ArgumentError('Voice reference audio is not configured');
    }
    final uri = Uri.tryParse(trimmedSource);
    if (uri == null) {
      throw ArgumentError.value(
          source, 'source', 'Invalid voice reference URI');
    }
    Uint8List bytes;
    if (uri.scheme == 'data') {
      final data = UriData.fromUri(uri);
      if (!data.mimeType.toLowerCase().startsWith('audio/')) {
        throw ArgumentError('Voice reference data URI must contain audio');
      }
      bytes = Uint8List.fromList(data.contentAsBytes());
      _checkDownloadSize(bytes.length);
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      bytes = await (downloader ?? _downloadAudio)(uri);
    } else {
      throw ArgumentError(
        'Voice reference must be an HTTP(S) or audio data URI',
      );
    }
    return normalizer(bytes);
  }

  static Future<Uint8List> _downloadAudio(Uri uri) async {
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Voice reference download failed with HTTP ${response.statusCode}',
          uri,
        );
      }
      final contentLength = response.contentLength;
      if (contentLength != null) _checkDownloadSize(contentLength);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        builder.add(chunk);
        _checkDownloadSize(builder.length);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }

  static void _checkDownloadSize(int bytes) {
    if (bytes > _maximumDownloadBytes) {
      throw ArgumentError('Voice reference exceeds the 16 MB size limit');
    }
  }
}

class VoiceReferenceService {
  static const _cacheKey = 'civitai_voice_blob_cache_v1';
  static final Map<String, Future<String>> _pendingResolutions = {};

  final CivitaiClient civitaiClient;
  final SharedPreferences? preferences;
  final VoiceAudioDownloader? downloader;
  final VoiceAudioNormalizer normalizer;
  final VoiceBlobUploader? uploader;
  final VoiceBlobRefresher? refresher;

  VoiceReferenceService({
    required this.civitaiClient,
    this.preferences,
    this.downloader,
    this.normalizer = prepareVoiceReferenceWav,
    this.uploader,
    this.refresher,
  });

  Future<String> resolve(String source) {
    final trimmedSource = source.trim();
    if (trimmedSource.isEmpty) {
      throw ArgumentError('Voice reference audio is not configured');
    }
    if (trimmedSource.startsWith('urn:air:')) {
      return Future.value(trimmedSource);
    }

    final accountKey = _digest(civitaiClient.apiToken);
    final sourceKey = '$accountKey:${_digest(trimmedSource)}';
    final existing = _pendingResolutions[sourceKey];
    if (existing != null) return existing;

    final resolution = _resolveSource(
      trimmedSource,
      accountKey: accountKey,
      sourceKey: sourceKey,
    );
    _pendingResolutions[sourceKey] = resolution;
    return resolution.whenComplete(() {
      if (identical(_pendingResolutions[sourceKey], resolution)) {
        _pendingResolutions.remove(sourceKey);
      }
    });
  }

  Future<void> invalidate(String source) async {
    final trimmedSource = source.trim();
    if (trimmedSource.isEmpty || trimmedSource.startsWith('urn:air:')) return;
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final cache = _readCache(prefs);
    final sources = _mapValue(cache['sources']);
    final blobs = _mapValue(cache['blobs']);
    final accountKey = _digest(civitaiClient.apiToken);
    final sourceKey = '$accountKey:${_digest(trimmedSource)}';
    final contentHash = sources.remove(sourceKey)?.toString();
    if (contentHash != null) {
      blobs.remove('$accountKey:$contentHash');
    }
    cache['sources'] = sources;
    cache['blobs'] = blobs;
    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  Future<String> _resolveSource(
    String source, {
    required String accountKey,
    required String sourceKey,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final cache = _readCache(prefs);
    final sources = _mapValue(cache['sources']);
    final blobs = _mapValue(cache['blobs']);
    final cachedHash = sources[sourceKey]?.toString();
    if (cachedHash != null) {
      final cached = _mapValue(blobs['$accountKey:$cachedHash']);
      final resolved = await _reuseCachedBlob(cached);
      if (resolved != null) {
        blobs['$accountKey:$cachedHash'] = cached;
        cache['blobs'] = blobs;
        await prefs.setString(_cacheKey, jsonEncode(cache));
        return resolved;
      }
    }

    final wavBytes = await VoiceReferenceLoader(
      downloader: downloader,
      normalizer: normalizer,
    ).loadWav(source);
    final contentHash = sha256.convert(wavBytes).toString();
    final blobKey = '$accountKey:$contentHash';
    final contentCached = _mapValue(blobs[blobKey]);
    final reused = await _reuseCachedBlob(contentCached);
    if (reused != null) {
      sources[sourceKey] = contentHash;
      blobs[blobKey] = contentCached;
      cache['sources'] = sources;
      cache['blobs'] = blobs;
      await prefs.setString(_cacheKey, jsonEncode(cache));
      return reused;
    }

    final blob = await (uploader ?? civitaiClient.blobs.uploadWav)(wavBytes);
    if (!blob.available) {
      throw StateError(
          'Civitai uploaded the voice reference but it is unavailable');
    }
    sources[sourceKey] = contentHash;
    blobs[blobKey] = _blobCacheValue(blob);
    cache['sources'] = sources;
    cache['blobs'] = blobs;
    await prefs.setString(_cacheKey, jsonEncode(cache));
    return blob.air;
  }

  Future<String?> _reuseCachedBlob(Map<String, dynamic> cached) async {
    final air = cached['air']?.toString() ?? '';
    final blobId = cached['blobId']?.toString() ?? '';
    if (air.isEmpty || blobId.isEmpty) return null;

    final expiresAt = DateTime.tryParse(cached['expiresAt']?.toString() ?? '');
    if (expiresAt == null ||
        expiresAt.isAfter(DateTime.now().add(const Duration(hours: 1)))) {
      return air;
    }

    try {
      final blob = await (refresher ?? civitaiClient.blobs.refresh)(blobId);
      if (!blob.available) return null;
      cached
        ..clear()
        ..addAll(_blobCacheValue(blob));
      return blob.air;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{
        'version': 1,
        'sources': <String, dynamic>{},
        'blobs': <String, dynamic>{},
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Replace malformed cache data instead of breaking voice generation.
    }
    return <String, dynamic>{
      'version': 1,
      'sources': <String, dynamic>{},
      'blobs': <String, dynamic>{},
    };
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _blobCacheValue(CivitaiBlob blob) => {
        'blobId': blob.id,
        'air': blob.air,
        if (blob.urlExpiresAt != null)
          'expiresAt': blob.urlExpiresAt!.toUtc().toIso8601String(),
      };

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
