import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moetalk/avatar_image.dart';

void main() {
  test('normalizes EXIF-oriented avatar data to upright PNG pixels', () {
    final source = img.Image(width: 2, height: 3)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 2, 0, 0, 255);
    source.exif.imageIfd.orientation = 3;
    final jpeg = img.encodeJpg(source, quality: 100);
    final uri = 'data:image/jpeg;base64,${base64Encode(jpeg)}';

    final normalizedBytes = normalizedAvatarBytes(uri);
    final normalized = img.decodePng(normalizedBytes)!;

    expect(normalized.exif.imageIfd.hasOrientation, isFalse);
    expect(normalized.width, 2);
    expect(normalized.height, 3);
    expect(normalized.getPixel(1, 2).r, greaterThan(200));
    expect(normalized.getPixel(0, 0).b, greaterThan(200));
  });
}
