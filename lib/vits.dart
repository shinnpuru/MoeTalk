// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_cpp_client.dart';
import 'civitai_client.dart';
import 'storage.dart';
import 'utils.dart';
import 'voice_reference_service.dart';

AudioPlayer? _activePlayer;
int _playbackOperation = 0;

class _MemoryAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  final String contentType;

  _MemoryAudioSource(this.bytes, {this.contentType = 'audio/wav'});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final rangeStart = (start ?? 0).clamp(0, bytes.length);
    final rangeEnd = (end ?? bytes.length).clamp(rangeStart, bytes.length);
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: rangeEnd - rangeStart,
      offset: rangeStart,
      stream: Stream.value(bytes.sublist(rangeStart, rangeEnd)),
      contentType: contentType,
    );
  }
}

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
    final uri = Uri.parse(audioUrl);
    final AudioSource source;
    if (uri.scheme == 'data') {
      final data = UriData.fromUri(uri);
      if (!data.mimeType.toLowerCase().startsWith('audio/')) {
        throw const FormatException('播放数据不是音频');
      }
      source = _MemoryAudioSource(
        Uint8List.fromList(data.contentAsBytes()),
        contentType: data.mimeType,
      );
    } else {
      source = AudioSource.uri(uri);
    }
    await player.setAudioSource(source);
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
  final refAudioSource = await getVitsPrompt();
  final refText = await getVitsPromptText();

  if (vitsConfig.backend == TtsBackend.audioCpp) {
    final referenceWav = await const VoiceReferenceLoader().loadWav(
      refAudioSource,
    );
    final audio = await AudioCppClient(
      baseUrl: vitsConfig.audioCppBaseUrl,
      defaultTimeout: const Duration(minutes: 8),
    ).createVoiceClone(
      model: vitsConfig.audioCppModel,
      text: query,
      referenceWav: referenceWav,
      referenceText: refText,
      language: 'Auto',
    );
    return 'data:audio/wav;base64,${base64Encode(audio)}';
  }

  final apiToken = vitsConfig.apiToken?.trim() ?? '';
  if (apiToken.isEmpty) {
    throw Exception('Civitai API token is not configured');
  }

  final civitaiClient = CivitaiClient(
    apiToken: apiToken,
    defaultTimeout: const Duration(minutes: 8),
  );
  final referenceService = VoiceReferenceService(
    civitaiClient: civitaiClient,
  );
  var refAudioUrl = await referenceService.resolve(refAudioSource);

  Future<String> submit() => civitaiClient.textToSpeech.createVoiceClone(
        text: query,
        refAudioUrl: refAudioUrl,
        refText: refText,
        language: 'Auto',
        timeout: const Duration(minutes: 8),
      );

  try {
    return await submit();
  } on CivitaiException catch (error) {
    final referenceUnavailable = error.statusCode == 400 &&
        error.message.toLowerCase().contains('download media');
    if (!referenceUnavailable || refAudioSource.startsWith('urn:air:')) {
      rethrow;
    }
    await referenceService.invalidate(refAudioSource);
    refAudioUrl = await referenceService.resolve(refAudioSource);
    return submit();
  }
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
