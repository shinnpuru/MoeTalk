import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/media_image.dart';
import 'package:moetalk/media_reference.dart';
import 'package:moetalk/media_store_io.dart';

void main() {
  test('stores generated image bytes and returns the file path', () async {
    final directory = await Directory.systemTemp.createTemp('moetalk_draw');
    try {
      final bytes = Uint8List.fromList([137, 80, 78, 71, 9, 9]);
      final reference = await storeGeneratedImage(
        bytes,
        'jpeg',
        directoryOverride: directory.path,
      );

      expect(reference.endsWith('.jpg'), isTrue);
      expect(reference.startsWith(directory.path), isTrue);
      expect(File(reference).existsSync(), isTrue);
      expect(await File(reference).readAsBytes(), bytes);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('falls back to an inline data URI when the directory is unusable',
      () async {
    final directory = await Directory.systemTemp.createTemp('moetalk_draw');
    try {
      // A file where a directory is expected makes the write fail.
      final filePath = '${directory.path}${Platform.pathSeparator}not_a_dir';
      await File(filePath).writeAsBytes([0]);

      final bytes = Uint8List.fromList([1, 2, 3]);
      final reference = await storeGeneratedImage(
        bytes,
        'png',
        directoryOverride: filePath,
      );

      expect(isDataImageReference(reference), isTrue);
      expect(decodeDataImageReference(reference), bytes);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('resolves file, data URI and remote references', () async {
    expect(mediaImageProvider('https://example.com/a.png'), isA<NetworkImage>());
    expect(
      mediaImageProvider('data:image/png;base64,${base64Encode([1, 2, 3])}'),
      isA<MemoryImage>(),
    );

    final directory = await Directory.systemTemp.createTemp('moetalk_draw');
    try {
      final path = '${directory.path}${Platform.pathSeparator}image.png';
      await File(path).writeAsBytes([1, 2, 3]);
      expect(mediaImageProvider(path), isA<FileImage>());
      expect(openableLocalMediaUri(path)?.scheme, 'file');
      expect(
        openableLocalMediaUri('${path}_missing'),
        isNull,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('normalises image extensions and MIME types', () {
    expect(sanitizeImageExtension('.JPEG'), 'jpg');
    expect(sanitizeImageExtension('webp'), 'webp');
    expect(sanitizeImageExtension('unknown'), 'png');
    expect(imageMimeType('jpg'), 'image/jpeg');
    expect(generatedImageFileName('jpg').endsWith('.jpg'), isTrue);
  });
}
