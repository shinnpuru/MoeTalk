import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moetalk/utils.dart';
import 'package:dio/dio.dart';
import 'storage.dart';
import 'package:just_audio/just_audio.dart';

Future<void> playAudio(BuildContext context, String audioUrl) async {
  try {
    final player = AudioPlayer();
    await player.setAudioSource(
      AudioSource.uri(Uri.parse(audioUrl)),
    );
    await player.play();
  } catch (e) {
    snackBarAlert(context, "播放错误: $e");
  }
}


Future<String?> getAudio(BuildContext context, String query) async {
  VitsConfig? vitsConfig = await getVitsConfig();
  String? url = await getVitsUrl();
  String? prompt = await getVitsPrompt();
  if (url == null || url.isEmpty) {
    url = 'https://indexteam-indextts-2-demo.hf.space/';
  }
  if(!url.endsWith('/')) {
    url += '/';
  }
  debugPrint(query);
  debugPrint(prompt);
  final dio = Dio(BaseOptions(baseUrl: url));
  final response = await dio.post(
    "/gradio_api/call/gen_single",
    data: jsonEncode({"data": [
        "Same as the voice reference",
        {"path":prompt,"meta":{"_type":"gradio.FileData"}}, // 语音参考
        query, // 语音内容
        null, // 表情参考
        1, // 表情强度
        vitsConfig.happy, // 情绪参数
        vitsConfig.angry,
        vitsConfig.sad,
        vitsConfig.afraid,
        vitsConfig.disgusted,
        vitsConfig.melancholic,
        vitsConfig.surprised,
        vitsConfig.calm,
        "", // Emotion description
        false, // Randomize emotion sampling
        120, // Max tokens per generation segment
        true, // do_sample
        0.8, // top_p
        30, // top_k
        0.8, // temperature 
        0, // length_penalty
        3, // num_beams
        10, // repetition_penalty
        1500 // max_mel_tokens
    ]
    }),
    options: Options(
      validateStatus: (status) => status! < 500, // 只处理2xx和3xx状态码
    ),
  );
  if (response.statusCode == 200) {
    // 取得音频数据
    final data = response.data.toString();
    String sessionHash = data.substring(11,data.length-1);
    debugPrint("/call/gen_single/$sessionHash");
    final Response audioResponse = await dio.get(
      "/gradio_api/call/gen_single/$sessionHash",
    );
    debugPrint("Session Hash: $sessionHash");
    
    // 匹配音频链接
    final regex = RegExp('/tmp/gradio/\\S+?\\.wav');
    final match = regex.firstMatch(audioResponse.data.toString());
    if (match != null) {
      final audioPath = "${url}gradio_api/file=${match.group(0)}";
      debugPrint("Audio path: $audioPath");

      return audioPath;
    } else {
      snackBarAlert(context, "未找到音频路径：${audioResponse.data.toString()}");
      return null;
    }
    
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
      snackBarAlert(context, "未找到音频数据");
      return "";
    }
  } catch (e) {
    snackBarAlert(context, "查询或播放音频时出错: $e");
    return "";
  }
}
