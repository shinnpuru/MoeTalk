import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:glint_audio_pure/glint_audio_pure.dart';

const _targetSampleRate = 24000;
const _maximumReferenceSeconds = 30;

/// Returns WAV input unchanged and converts MPEG-1 Layer III MP3 to a
/// Civitai-friendly 24 kHz, mono, 16-bit PCM WAV on every Flutter platform.
Future<Uint8List> prepareVoiceReferenceWav(Uint8List sourceBytes) async {
  if (_matches(sourceBytes, const [0x52, 0x49, 0x46, 0x46], 0) &&
      _matches(sourceBytes, const [0x57, 0x41, 0x56, 0x45], 8)) {
    return sourceBytes;
  }
  if (!_looksLikeMp3(sourceBytes)) {
    throw const FormatException('语音参考只支持 WAV 或 MP3 文件');
  }

  return compute(_decodeMp3ToWav, sourceBytes);
}

Uint8List _decodeMp3ToWav(Uint8List sourceBytes) {
  final decoded = mp3Decode(sourceBytes);
  if (decoded.channels < 1 ||
      decoded.sampleRate < 1 ||
      decoded.samples.length < decoded.channels) {
    throw const FormatException(
      '无法解码 MP3；目前支持 MPEG-1 Layer III 格式',
    );
  }

  final sourceFrames = decoded.samples.length ~/ decoded.channels;
  final durationSeconds = sourceFrames / decoded.sampleRate;
  if (durationSeconds > _maximumReferenceSeconds) {
    throw FormatException(
      '语音参考不能超过 $_maximumReferenceSeconds 秒'
      '（当前 ${durationSeconds.toStringAsFixed(1)} 秒）',
    );
  }

  final targetFrames =
      (sourceFrames * _targetSampleRate / decoded.sampleRate).round();
  final pcm = Int16List(targetFrames);
  final sourceStep = decoded.sampleRate / _targetSampleRate;

  double monoSample(int frame) {
    var sum = 0.0;
    final offset = frame * decoded.channels;
    for (var channel = 0; channel < decoded.channels; channel++) {
      sum += decoded.samples[offset + channel];
    }
    return sum / decoded.channels;
  }

  for (var targetFrame = 0; targetFrame < targetFrames; targetFrame++) {
    final sourcePosition = targetFrame * sourceStep;
    final left = sourcePosition.floor().clamp(0, sourceFrames - 1);
    final right = (left + 1).clamp(0, sourceFrames - 1);
    final fraction = sourcePosition - left;
    final leftSample = monoSample(left);
    final sample = (leftSample + (monoSample(right) - leftSample) * fraction)
        .clamp(-1.0, 1.0);
    pcm[targetFrame] =
        sample < 0 ? (sample * 32768).round() : (sample * 32767).round();
  }
  return _encodeMonoWav(pcm);
}

bool _looksLikeMp3(Uint8List bytes) {
  if (_matches(bytes, const [0x49, 0x44, 0x33], 0)) return true;
  final scanLength = bytes.length.clamp(0, 64 * 1024);
  for (var index = 0; index + 1 < scanLength; index++) {
    if (bytes[index] == 0xff && (bytes[index + 1] & 0xe0) == 0xe0) {
      return true;
    }
  }
  return false;
}

bool _matches(Uint8List bytes, List<int> signature, int offset) {
  if (bytes.length < offset + signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[offset + index] != signature[index]) return false;
  }
  return true;
}

Uint8List _encodeMonoWav(Int16List samples) {
  const headerSize = 44;
  const bytesPerSample = 2;
  final dataLength = samples.length * bytesPerSample;
  final output = Uint8List(headerSize + dataLength);
  final data = ByteData.sublistView(output);

  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      output[offset + index] = value.codeUnitAt(index);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _targetSampleRate, Endian.little);
  data.setUint32(28, _targetSampleRate * bytesPerSample, Endian.little);
  data.setUint16(32, bytesPerSample, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(
      headerSize + index * bytesPerSample,
      samples[index],
      Endian.little,
    );
  }
  return output;
}
