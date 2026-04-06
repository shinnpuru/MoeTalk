import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moetalk/utils.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'storage.dart';
final FlutterTts _flutterTts = FlutterTts();
bool _ttsInitialized = false;

Future<void> _initTts() async {
  if (_ttsInitialized) return;

  await _flutterTts.awaitSpeakCompletion(true);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.ambient,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.voicePrompt,
    );
  }

  _flutterTts.setStartHandler(() {
    debugPrint('TTS started');
  });
  _flutterTts.setCompletionHandler(() {
    debugPrint('TTS completed');
  });
  _flutterTts.setErrorHandler((msg) {
    debugPrint('TTS error: $msg');
  });

  _ttsInitialized = true;
}

Future<void> _applyTtsConfig(VitsConfig config) async {
  if (config.language != null && config.language!.isNotEmpty) {
    await _flutterTts.setLanguage(config.language!);
  }
  await _flutterTts.setSpeechRate(config.speechRate ?? 0.5);
  await _flutterTts.setVolume(config.volume ?? 1.0);
  await _flutterTts.setPitch(config.pitch ?? 1.0);

  if ((config.voiceName ?? '').isNotEmpty ||
      (config.voiceLocale ?? '').isNotEmpty) {
    final voice = <String, String>{};
    if ((config.voiceName ?? '').isNotEmpty) {
      voice['name'] = config.voiceName!;
    }
    if ((config.voiceLocale ?? '').isNotEmpty) {
      voice['locale'] = config.voiceLocale!;
    }
    await _flutterTts.setVoice(voice);
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await _flutterTts.setSharedInstance(config.sharedInstance ?? true);
  }
}

Future<void> playAudio(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;

  try {
    await _initTts();
    final vitsConfig = await getVitsConfig();
    await _applyTtsConfig(vitsConfig);

    await _flutterTts.stop();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _flutterTts.speak(text, focus: vitsConfig.focus ?? true);
    } else {
      await _flutterTts.speak(text);
    }
  } catch (e) {
    snackBarAlert(context, "播放错误: $e");
  }
}

Future<String?> getAudio(BuildContext context, String query) async {
  if (query.trim().isEmpty) return null;
  return query;
}

Future<String> queryAndPlayAudio(BuildContext context, String query) async {
  try {
    final text = await getAudio(context, query);
    if (text != null && text.isNotEmpty) {
      await playAudio(context, text);
      return text;
    }
    return "";
  } catch (e) {
    snackBarAlert(context, "语音播放出错: $e");
    return "";
  }
}
