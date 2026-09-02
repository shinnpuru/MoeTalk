import 'dart:typed_data';

/// Transcoding is intentionally disabled for now. Validate the downloaded
/// bytes instead of trusting a `.wav` suffix or an HTTP content type.
Future<Uint8List> prepareVoiceReferenceWav(Uint8List sourceBytes) async {
  bool matches(List<int> signature, int offset) {
    if (sourceBytes.length < offset + signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (sourceBytes[offset + index] != signature[index]) return false;
    }
    return true;
  }

  final isWav = matches(const [0x52, 0x49, 0x46, 0x46], 0) &&
      matches(const [0x57, 0x41, 0x56, 0x45], 8);
  if (!isWav) {
    throw const FormatException(
      '语音参考只支持 WAV 文件；目前未启用 OGG/MP3 转码',
    );
  }
  return sourceBytes;
}
