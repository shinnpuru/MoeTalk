import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'civitai_client.dart';
import 'storage.dart';
import 'utils.dart';

AudioPlayer? _activePlayer;
int _playbackOperation = 0;

Future<void> stopAudio() async {
  _playbackOperation++;
  final player = _activePlayer;
  _activePlayer = null;
  if (player != null) {
    await player.stop();
    await player.dispose();
  }
}

Future<void> playAudio(BuildContext context, String audioUrl) async {
  final operation = ++_playbackOperation;
  final previousPlayer = _activePlayer;
  _activePlayer = null;
  if (previousPlayer != null) {
    await previousPlayer.stop();
    await previousPlayer.dispose();
  }
  if (operation != _playbackOperation) return;

  final player = AudioPlayer();
  _activePlayer = player;
  try {
    await player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
    if (operation != _playbackOperation) return;
    await player.play();
  } catch (e) {
    if (operation == _playbackOperation && context.mounted) {
      snackBarAlert(context, "播放错误: $e");
    }
  } finally {
    if (identical(_activePlayer, player)) {
      _activePlayer = null;
      await player.dispose();
    }
  }
}

Future<String?> getAudio(BuildContext context, String query) async {
  final vitsConfig = await getVitsConfig();
  final apiToken = vitsConfig.apiToken?.trim() ?? '';
  if (apiToken.isEmpty) {
    throw Exception('Civitai API token is not configured');
  }

  final refAudioUrl = await getVitsPrompt();
  final refText = await getVitsPromptText();
  final civitaiClient = CivitaiClient(
    apiToken: apiToken,
    defaultTimeout: const Duration(minutes: 8),
  );

  return civitaiClient.textToSpeech.createVoiceClone(
    text: query,
    refAudioUrl: refAudioUrl,
    refText: refText,
    language: vitsConfig.language,
    timeout: const Duration(minutes: 8),
  );
}

Future<String> queryAndPlayAudio(BuildContext context, String query) async {
  try {
    final audio = await getAudio(context, query);
    if (audio == null || audio.isEmpty) {
      return "";
    }
    if (!context.mounted) {
      return "";
    }
    await playAudio(context, audio);
    return audio;
  } catch (e) {
    if (context.mounted) {
      snackBarAlert(context, "查询或播放音频时出错: $e");
    }
    return "";
  }
}
