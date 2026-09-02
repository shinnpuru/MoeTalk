import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glint_audio_pure/glint_audio_pure.dart';
import 'package:moetalk/voice_audio_normalizer.dart';

void main() {
  test('accepts WAV bytes without transcoding', () async {
    final wav = Uint8List.fromList([
      ...ascii.encode('RIFF'),
      0,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);

    expect(identical(await prepareVoiceReferenceWav(wav), wav), isTrue);
  });

  test('converts MP3 input to 24 kHz mono WAV', () async {
    final pcm = Float64List.fromList(List.generate(
      44100,
      (index) => math.sin(2 * math.pi * 440 * index / 44100) * 0.25,
    ));
    final mp3 = mp3EncodeMono(pcm, sampleRate: 44100, bitrate: 64);
    final wav = await prepareVoiceReferenceWav(mp3);
    final header = ByteData.sublistView(wav);

    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 24000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(wav.length, greaterThan(44000));
  });

  test('rejects unsupported audio formats', () {
    final ogg = Uint8List.fromList(ascii.encode('OggS'));

    expect(
      () => prepareVoiceReferenceWav(ogg),
      throwsA(isA<FormatException>()),
    );
  });
}
