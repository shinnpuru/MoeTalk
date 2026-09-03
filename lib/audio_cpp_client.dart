import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AudioCppException implements Exception {
  final int? statusCode;
  final String message;

  const AudioCppException(this.message, {this.statusCode});

  @override
  String toString() => statusCode == null
      ? 'audio.cpp: $message'
      : 'audio.cpp HTTP $statusCode: $message';
}

class AudioCppClient {
  static const maximumInlineReferenceBytes = 5 * 1024 * 1024;

  final String baseUrl;
  final Duration defaultTimeout;
  final http.Client? httpClient;

  const AudioCppClient({
    required this.baseUrl,
    this.defaultTimeout = const Duration(minutes: 8),
    this.httpClient,
  });

  Future<void> checkHealth() async {
    final response = await _get('/health', const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseException(response);
    }
  }

  Future<List<String>> listModels() async {
    final response = await _get('/v1/models', const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseException(response);
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('missing data array');
      }
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((entry) => entry['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw AudioCppException('模型列表响应格式无效：$error');
    }
  }

  Future<Uint8List> createVoiceClone({
    required String model,
    required String text,
    required Uint8List referenceWav,
    String? referenceText,
    String language = 'Auto',
  }) async {
    final normalizedModel = model.trim();
    final normalizedText = text.trim();
    if (normalizedModel.isEmpty) {
      throw const AudioCppException('未配置模型 ID');
    }
    if (normalizedText.isEmpty) {
      throw const AudioCppException('合成文本不能为空');
    }
    if (referenceWav.isEmpty) {
      throw const AudioCppException('参考音频不能为空');
    }
    if (referenceWav.length > maximumInlineReferenceBytes) {
      throw const AudioCppException('参考音频超过 audio.cpp 的 5 MiB 限制');
    }

    final normalizedReferenceText = referenceText?.trim() ?? '';
    final languageName = _languageName(language);
    final payload = <String, dynamic>{
      'model': normalizedModel,
      'input': normalizedText,
      'voice_ref': <String, String>{
        'type': 'base64',
        'data': base64Encode(referenceWav),
      },
      if (normalizedReferenceText.isNotEmpty)
        'reference_text': normalizedReferenceText,
      if (normalizedReferenceText.isEmpty)
        'options': const <String, dynamic>{'x_vector_only_mode': true},
      if (languageName != null) 'language': languageName,
    };

    final response = await _postJson('/v1/audio/speech', payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseException(response);
    }
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.startsWith('audio/')) {
      throw AudioCppException(
        '语音接口返回了非音频内容（${contentType.isEmpty ? '无 Content-Type' : contentType}）',
        statusCode: response.statusCode,
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw const AudioCppException('语音接口返回了空音频');
    }
    return response.bodyBytes;
  }

  Future<http.Response> _get(String path, Duration timeout) {
    final client = httpClient;
    final request = client == null
        ? http
            .get(_endpoint(path), headers: const {'Accept': 'application/json'})
        : client.get(_endpoint(path),
            headers: const {'Accept': 'application/json'});
    return request.timeout(timeout);
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'audio/wav',
    };
    final encoded = jsonEncode(body);
    final client = httpClient;
    final request = client == null
        ? http.post(_endpoint(path), headers: headers, body: encoded)
        : client.post(_endpoint(path), headers: headers, body: encoded);
    return request.timeout(defaultTimeout);
  }

  Uri _endpoint(String path) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$normalized$path');
    if (normalized.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      throw const AudioCppException('Server 地址无效');
    }
    return uri;
  }

  static String? _languageName(String language) {
    switch (language.trim().toLowerCase()) {
      case '':
      case 'auto':
        return null;
      default:
        return language.trim();
    }
  }

  static AudioCppException _responseException(http.Response response) {
    var message = response.reasonPhrase ?? '请求失败';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          message = error['message'].toString();
        } else if (decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      }
    } catch (_) {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      if (body.isNotEmpty) message = body;
    }
    return AudioCppException(message, statusCode: response.statusCode);
  }
}
