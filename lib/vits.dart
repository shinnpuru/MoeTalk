import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:moetalk/utils.dart';
import 'package:dio/dio.dart';
import 'storage.dart';
import 'package:just_audio/just_audio.dart';

Future<void> playAudio(BuildContext context, String audioUrl) async {
  try {
    final Uri uri = audioUrl.startsWith('http') || audioUrl.startsWith('data:')
        ? Uri.parse(audioUrl)
        : Uri.file(audioUrl);
    final player = AudioPlayer();
    await player.setAudioSource(
      AudioSource.uri(uri),
    );
    await player.play();
  } catch (e) {
    snackBarAlert(context, "播放错误: $e");
  }
}

String _guessFormatByContentType(String? contentType, String fallback) {
  final String c = (contentType ?? '').toLowerCase();
  if (c.contains('audio/wav') || c.contains('audio/x-wav')) return 'wav';
  if (c.contains('audio/mpeg') || c.contains('audio/mp3')) return 'mp3';
  if (c.contains('audio/pcm') || c.contains('audio/l16')) return 'pcm';
  return fallback;
}

String _mimeByFormat(String format) {
  switch (format.toLowerCase()) {
    case 'wav':
      return 'audio/wav';
    case 'pcm':
      return 'audio/L16';
    case 'mp3':
    default:
      return 'audio/mpeg';
  }
}

String _toDataUri(Uint8List bytes, String format) {
  return 'data:${_mimeByFormat(format)};base64,${base64Encode(bytes)}';
}

String? _extractAudioUrlFromJson(dynamic data) {
  if (data is! Map<String, dynamic>) return null;
  final String? u1 = data['audio_url']?.toString();
  final String? u2 = data['url']?.toString();
  final String? u3 = (data['data'] is Map<String, dynamic>)
      ? (data['data']['url']?.toString())
      : null;
  return u1 ?? u2 ?? u3;
}

String? _extractAudioBase64FromJson(dynamic data) {
  if (data is! Map<String, dynamic>) return null;
  final String? b64 = data['audio_base64']?.toString() ??
      data['audio']?.toString() ??
      data['data']?.toString();
  if (b64 == null || b64.isEmpty) return null;
  if (b64.startsWith('data:')) return b64;
  return b64;
}

Uint8List? _extractAudioBytesFromJson(dynamic data) {
  if (data is! Map<String, dynamic>) return null;
  final String? b64 = _extractAudioBase64FromJson(data);
  if (b64 == null || b64.isEmpty) return null;
  if (b64.startsWith('data:')) {
    final int comma = b64.indexOf(',');
    if (comma > -1 && comma + 1 < b64.length) {
      try {
        return base64Decode(b64.substring(comma + 1));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

Future<String?> getAudio(BuildContext context, String query) async {
  VitsConfig vitsConfig = await getVitsConfig();
  String? url = await getVitsUrl();
  if (url == null || url.isEmpty) {
    url = 'https://api.x.ai/v1/tts';
  }

  final Map<String, dynamic> payload = {
    'text': query,
    'voice_id': (vitsConfig.voiceId == null || vitsConfig.voiceId!.isEmpty)
        ? 'eve'
        : vitsConfig.voiceId,
    'language': (vitsConfig.language == null || vitsConfig.language!.isEmpty)
        ? 'zh'
        : vitsConfig.language,
  };

  final headers = <String, dynamic>{
    'Content-Type': 'application/json',
    'Accept': 'audio/mpeg, audio/wav, application/json',
  };
  if (vitsConfig.apiKey != null && vitsConfig.apiKey!.isNotEmpty) {
    headers['Authorization'] = 'Bearer ${vitsConfig.apiKey}';
  }

  final dio = Dio();
  final response = await dio.post(
    url,
    data: jsonEncode(payload),
    options: Options(
      headers: headers,
      responseType: ResponseType.bytes,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
    final String contentType = response.headers.value('content-type') ?? '';
    final dynamic data = response.data;

    if (contentType.contains('application/json')) {
      final String text = utf8.decode((data as List).cast<int>());
      final dynamic jsonData = jsonDecode(text);
      final String? remoteUrl = _extractAudioUrlFromJson(jsonData);
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        return remoteUrl;
      }
      final Uint8List? jsonBytes = _extractAudioBytesFromJson(jsonData);
      if (jsonBytes != null) {
        final String format = _guessFormatByContentType(
          contentType,
          (vitsConfig.audioFormat == null || vitsConfig.audioFormat!.isEmpty)
              ? 'mp3'
              : vitsConfig.audioFormat!,
        );
        return _toDataUri(jsonBytes, format);
      }
      snackBarAlert(context, '未在 JSON 响应中找到音频数据');
      return null;
    }

    final List<int> bytes = (data as List).cast<int>();
    final String format = _guessFormatByContentType(
      contentType,
      (vitsConfig.audioFormat == null || vitsConfig.audioFormat!.isEmpty)
          ? 'mp3'
          : vitsConfig.audioFormat!,
    );
    return _toDataUri(Uint8List.fromList(bytes), format);
  } else {
    snackBarAlert(context, "请求失败: ${response.statusCode} ${response.toString()}");
    return null;
  }
}

Future<String> queryAndPlayAudio(BuildContext context, String query) async {
  try {
    final audio = await getAudio(context, query);
    if (audio != null && audio.isNotEmpty) {
      await playAudio(context, audio);
      return audio;
    } else {
      return "";
    }
  } catch (e) {
    snackBarAlert(context, "查询或播放音频时出错: $e");
    return "";
  }
}
