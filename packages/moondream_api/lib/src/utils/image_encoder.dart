import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Utilities for encoding images to base64 format required by Moondream API
class ImageEncoder {
  /// Encode image file to base64 with data URI prefix
  ///
  /// The Moondream API requires images in the format:
  /// `data:image/jpeg;base64,{BASE64_DATA}`
  static String encodeFile(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw ArgumentError('Image file not found: $imagePath');
    }

    final bytes = file.readAsBytesSync();
    final mimeType = _detectMimeType(imagePath);

    return _encodeBytes(bytes, mimeType);
  }

  /// Encode image bytes to base64 with data URI prefix
  static String encodeBytes(Uint8List bytes, {String mimeType = 'image/jpeg'}) {
    return _encodeBytes(bytes, mimeType);
  }

  /// Encode base64 string (without data URI) to proper format
  static String encodeBase64String(
    String base64Data, {
    String mimeType = 'image/jpeg',
  }) {
    // Remove any existing data URI prefix
    final cleanBase64 = base64Data.replaceFirst(
      RegExp(r'^data:image/[^;]+;base64,'),
      '',
    );
    return 'data:$mimeType;base64,$cleanBase64';
  }

  static String _encodeBytes(Uint8List bytes, String mimeType) {
    if (bytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }

    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Image size exceeds 10MB limit');
    }

    final base64Image = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Image';
  }

  /// Detect MIME type from file extension
  static String _detectMimeType(String imagePath) {
    final extension = imagePath.split('.').last.toLowerCase();

    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg', // Default to JPEG
    };
  }

  /// Validate if a string is a properly formatted data URI
  static bool isValidDataUri(String dataUri) {
    return RegExp(
      r'^data:image/[^;]+;base64,[A-Za-z0-9+/]+=*$',
    ).hasMatch(dataUri);
  }

  /// Extract MIME type from data URI
  static String? extractMimeType(String dataUri) {
    final match = RegExp(r'^data:(image/[^;]+);base64,').firstMatch(dataUri);
    return match?.group(1);
  }
}
