import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:momotalk/utils.dart';
import 'package:dio/dio.dart';
import 'storage.dart';
import 'package:just_audio/just_audio.dart';

Future<List<int>> base64StringToUint8List(String base64String) async {
  return base64Decode(base64String);
}

class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;

  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;

    return StreamAudioResponse(
      sourceLength: null,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/wav', // 或根据实际音频格式修改
    );
  }
}

Future<void> playBase64Audio(BuildContext context, String base64String) async {
  try {
    // strip 'data:audio/wav;base64,' prefix if it exists
    if (base64String.startsWith('data:audio/wav;base64,')) {
      base64String = base64String.replaceFirst('data:audio/wav;base64,', '');
    }
    final audioBytes = await base64StringToUint8List(base64String);
    final player = AudioPlayer();
    await player.setAudioSource(MyCustomSource(audioBytes));
    await player.play();
  } catch (e) {
    snackBarAlert(context, "播放错误: $e");
  }
}


Future<String?> getAudioBase64(BuildContext context, String query) async {
  VitsConfig? vitsConfig = await getVitsConfig();
  String? value = await getVitsUrl();
  if (value == null || value.isEmpty) {
    value = 'https://shinnpuru-vits-models.hf.space/';
  }
  if(!value.endsWith('/')) {
    value += '/';
  }
  print(query);
  final dio = Dio(BaseOptions(baseUrl: value));
  final response = await dio.post(
    "/api/${vitsConfig.model}",
    data: jsonEncode({"data": [
        query, // 语音内容
        vitsConfig.language, // 语言
        vitsConfig.noiseScale ?? 0.6, // 噪声缩放
        vitsConfig.noiseScaleW ?? 0.7, // 噪声缩放W
        vitsConfig.lengthScale ?? 1.2, // 长度缩放
        false, // 是否使用音频增强
    ]
    }),
    options: Options(
      validateStatus: (status) => status! < 500, // 只处理2xx和3xx状态码
    ),
  );
  if (response.statusCode == 200) {
    snackBarAlert(context, "请求成功: ${response.statusCode}");
    return response.data['data'][1] as String?;
  } else {
    snackBarAlert(context, "请求失败: ${response.statusCode} ${response.toString()}");
    return null;
  }
}

Future<void> queryAndPlayAudio(BuildContext context, String query) async {
  try {
    final audioBase64 = await getAudioBase64(context, query);
    if (audioBase64 != null && audioBase64.isNotEmpty) {
      await playBase64Audio(context, audioBase64);
    } else {
      snackBarAlert(context, "未找到音频数据");
    }
  } catch (e) {
    snackBarAlert(context, "查询或播放音频时出错: $e");
  }
}
