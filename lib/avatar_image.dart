import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

Uint8List normalizedAvatarBytes(String dataUri) {
  final separator = dataUri.indexOf(',');
  if (separator < 0) {
    throw const FormatException('Invalid avatar data URI');
  }

  final bytes = base64Decode(dataUri.substring(separator + 1));
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported avatar image');
  }

  // Re-encoding to PNG bakes camera EXIF orientation into the pixels. This
  // avoids Android image decoders applying the orientation inconsistently.
  return Uint8List.fromList(img.encodePng(decoded));
}

ImageProvider avatarImageProvider(String avatar) {
  if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return NetworkImage(avatar);
  }
  if (avatar.startsWith('data:image/')) {
    try {
      return MemoryImage(normalizedAvatarBytes(avatar));
    } on FormatException {
      // Fall through to the bundled avatar for malformed imported data.
    }
  }
  return const AssetImage('assets/avatar.png');
}
