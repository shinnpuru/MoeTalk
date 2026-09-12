import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'media_reference.dart';

/// On web there is no writable app directory, so generated images stay inline
/// as `data:` URIs; browsers render them like any other image source.
Future<String> storeGeneratedImage(
  Uint8List bytes,
  String extension, {
  String? directoryOverride,
}) async =>
    generatedImageDataUri(bytes, sanitizeImageExtension(extension));

/// Web never produces local file references.
ImageProvider? localMediaImageProvider(String reference) => null;

/// Web never produces local file references.
Uri? openableLocalMediaUri(String reference) => null;
