import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'media_reference.dart';

/// Writes generated image bytes into the app data directory and returns the
/// absolute path, which is what the chat history stores.
///
/// Falls back to an inline `data:` URI when the filesystem is unavailable.
Future<String> storeGeneratedImage(
  Uint8List bytes,
  String extension, {
  String? directoryOverride,
}) async {
  final resolvedExtension = sanitizeImageExtension(extension);
  try {
    final directory = await _resolveDirectory(directoryOverride);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${generatedImageFileName(resolvedExtension)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (error) {
    debugPrint('Failed to store generated image: $error');
    return generatedImageDataUri(bytes, resolvedExtension);
  }
}

Future<Directory> _resolveDirectory(String? directoryOverride) async {
  final override = directoryOverride?.trim() ?? '';
  if (override.isNotEmpty) {
    final directory = Directory(override);
    await directory.create(recursive: true);
    return directory;
  }
  Directory base;
  try {
    base = await getApplicationSupportDirectory();
  } catch (_) {
    base = await getTemporaryDirectory();
  }
  final directory =
      Directory('${base.path}${Platform.pathSeparator}generated_images');
  await directory.create(recursive: true);
  return directory;
}

/// An [ImageProvider] for a locally stored reference, or null when the
/// reference is not a local file.
ImageProvider? localMediaImageProvider(String reference) {
  final path = reference.trim();
  if (path.isEmpty) return null;
  if (path.startsWith('file://')) {
    final uri = Uri.tryParse(path);
    return uri == null ? null : FileImage(File.fromUri(uri));
  }
  return FileImage(File(path));
}

/// A `file://` URI usable by `url_launcher`, or null when unusable.
Uri? openableLocalMediaUri(String reference) {
  final path = reference.trim();
  if (path.isEmpty) return null;
  final uri = path.startsWith('file://') ? Uri.tryParse(path) : Uri.file(path);
  if (uri == null || uri.scheme != 'file') return null;
  return File.fromUri(uri).existsSync() ? uri : null;
}
