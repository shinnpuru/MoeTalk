import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Helpers shared by the platform-specific media stores and the image widget.
///
/// A generated image is referenced in the chat history either by an absolute
/// local file path (desktop/mobile) or by a `data:` URI (web, where the
/// filesystem and `Image.file` are unavailable).
const String _dataImagePrefix = 'data:image/';

bool isDataImageReference(String reference) =>
    reference.trim().startsWith(_dataImagePrefix);

bool isRemoteImageReference(String reference) {
  final ref = reference.trim().toLowerCase();
  return ref.startsWith('http://') || ref.startsWith('https://');
}

bool isInlineImageReference(String reference) =>
    isDataImageReference(reference) || isRemoteImageReference(reference);

/// Normalises a server-reported format (`png`, `jpeg`, `webp`, ...) into a
/// file extension.
String sanitizeImageExtension(String extension) {
  final normalized = extension.trim().toLowerCase().replaceAll('.', '');
  switch (normalized) {
    case 'jpg':
    case 'jpeg':
      return 'jpg';
    case 'webp':
      return 'webp';
    case 'gif':
      return 'gif';
    case 'png':
      return 'png';
    default:
      return 'png';
  }
}

String imageMimeType(String extension) {
  switch (sanitizeImageExtension(extension)) {
    case 'jpg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/png';
  }
}

String generatedImageDataUri(Uint8List bytes, String extension) =>
    'data:${imageMimeType(extension)};base64,${base64Encode(bytes)}';

String generatedImageFileName(String extension) =>
    'draw_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 30)}'
    '.${sanitizeImageExtension(extension)}';

/// Decodes the payload of an image `data:` URI, or null when malformed.
Uint8List? decodeDataImageReference(String reference) {
  final separator = reference.indexOf(',');
  if (separator < 0) return null;
  try {
    return base64Decode(reference.substring(separator + 1));
  } on FormatException {
    return null;
  }
}

final Random _random = Random();
