import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Claude API image size limits
class ClaudeImageLimits {
  /// Maximum base64-encoded size allowed by Claude API
  static const int maxBase64Size = 5 * 1024 * 1024; // 5MB

  /// Maximum dimension for efficient processing
  static const int maxDimension = 2000;

  /// Minimum JPEG quality to maintain usability
  static const int minJpegQuality = 50;

  /// Quality steps for progressive compression
  static const List<int> qualitySteps = [95, 85, 75, 65, 55, 50];

  /// Dimension reduction factors for progressive compression
  static const List<double> dimensionFactors = [1.0, 0.75, 0.5, 0.35, 0.25];

  /// Absolute minimum dimension factor for last-resort compression
  /// Chosen to ensure even 4K images (3840×2160) compress to <5MB
  static const double emergencyDimensionFactor = 0.15;
}

/// Result of image validation/compression
class ImageValidationResult {
  final Uint8List bytes;
  final String mimeType;
  final bool wasCompressed;
  final String? compressionNote;

  const ImageValidationResult({
    required this.bytes,
    required this.mimeType,
    this.wasCompressed = false,
    this.compressionNote,
  });
}

/// Validates and compresses images to fit Claude API limits.
class ImageValidator {
  /// Validates image size and compresses if needed.
  /// Never throws - always returns a usable result.
  static ImageValidationResult ensureWithinLimits(
    Uint8List bytes, {
    String mimeType = 'image/png',
    void Function(String message)? onWarning,
  }) {
    // Quick check: already within limit?
    final base64Size = _estimateBase64Size(bytes.length);
    if (base64Size <= ClaudeImageLimits.maxBase64Size) {
      return ImageValidationResult(bytes: bytes, mimeType: mimeType);
    }

    onWarning?.call(
      'Image size (${_formatSize(bytes.length)}) exceeds Claude API limit. Auto-compressing...',
    );

    return _compressProgressively(bytes, mimeType, onWarning);
  }

  static ImageValidationResult _compressProgressively(
    Uint8List originalBytes,
    String originalMimeType,
    void Function(String)? onWarning,
  ) {
    final image = _decodeImage(originalBytes, originalMimeType);
    if (image == null) {
      onWarning?.call(
        'Could not decode image for compression - applying emergency truncation',
      );

      // Calculate maximum safe raw size for 5MB base64 limit
      final maxSafeRawSize = (ClaudeImageLimits.maxBase64Size * 3 ~/ 4);

      if (originalBytes.length > maxSafeRawSize) {
        return ImageValidationResult(
          bytes: Uint8List.sublistView(originalBytes, 0, maxSafeRawSize),
          mimeType: originalMimeType,
          wasCompressed: true,
          compressionNote: 'Emergency truncation applied (invalid image data)',
        );
      }

      return ImageValidationResult(
        bytes: originalBytes,
        mimeType: originalMimeType,
      );
    }

    // Try each combination of dimension factor and quality
    for (final dimFactor in ClaudeImageLimits.dimensionFactors) {
      for (final quality in ClaudeImageLimits.qualitySteps) {
        final result = _tryCompression(image, dimFactor, quality);

        if (_estimateBase64Size(result.length) <=
            ClaudeImageLimits.maxBase64Size) {
          final note = dimFactor < 1.0 || quality < 95
              ? 'Compressed: ${(dimFactor * 100).round()}% size, $quality% quality'
              : null;
          if (note != null) onWarning?.call(note);

          return ImageValidationResult(
            bytes: result,
            mimeType: 'image/jpeg',
            wasCompressed: true,
            compressionNote: note,
          );
        }
      }
    }

    // Last resort: aggressive compression
    onWarning?.call('Applying aggressive compression');
    final aggressive = _tryCompression(
      image,
      ClaudeImageLimits.emergencyDimensionFactor,
      ClaudeImageLimits.minJpegQuality,
    );

    return ImageValidationResult(
      bytes: aggressive,
      mimeType: 'image/jpeg',
      wasCompressed: true,
      compressionNote: 'Aggressively compressed (15% size, 50% quality)',
    );
  }

  static Uint8List _tryCompression(
    img.Image image,
    double dimensionFactor,
    int quality,
  ) {
    var processedImage = image;

    if (dimensionFactor < 1.0) {
      final newWidth = (image.width * dimensionFactor).round().clamp(
        100,
        image.width,
      );
      final newHeight = (image.height * dimensionFactor).round().clamp(
        100,
        image.height,
      );
      processedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    return Uint8List.fromList(img.encodeJpg(processedImage, quality: quality));
  }

  static img.Image? _decodeImage(Uint8List bytes, String mimeType) {
    try {
      if (mimeType.contains('png')) return img.decodePng(bytes);
      if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
        return img.decodeJpg(bytes);
      }
      if (mimeType.contains('gif')) return img.decodeGif(bytes);
      if (mimeType.contains('webp')) return img.decodeWebP(bytes);
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  static int _estimateBase64Size(int rawSize) => (rawSize * 4 / 3).ceil();

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
