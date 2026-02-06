/// Message type for the Vide interface boundary.
///
/// Replaces claude_sdk's Message at the public API surface so that
/// consumers of vide_interface do not need a claude_sdk dependency.
library;

/// An attachment to a message (e.g., an image file or pasted text).
class VideAttachment {
  /// The attachment type (e.g., 'image', 'document', 'file').
  final String type;

  /// The file path for file-based attachments.
  final String? filePath;

  /// Text content (e.g., for pasted documents or base64-encoded images).
  final String? content;

  /// Raw content bytes (e.g., for inline images).
  final List<int>? bytes;

  /// MIME type of the attachment.
  final String? mimeType;

  const VideAttachment({
    required this.type,
    this.filePath,
    this.content,
    this.bytes,
    this.mimeType,
  });

  /// Create a file attachment.
  const VideAttachment.file(String path)
    : type = 'file',
      filePath = path,
      content = null,
      bytes = null,
      mimeType = null;

  /// Create an image attachment from a file path.
  factory VideAttachment.image(String path) {
    return VideAttachment(
      type: 'image',
      filePath: path,
      mimeType: _detectMediaType(path),
    );
  }

  /// Create a document attachment from text content.
  const VideAttachment.documentText({required String text, String? title})
    : type = 'document',
      content = text,
      mimeType = 'text/plain',
      filePath = title,
      bytes = null;

  static String? _detectMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }
}

/// A message sent to or from an agent.
class VideMessage {
  /// The text content of the message.
  final String text;

  /// Optional attachments (images, files, etc.).
  final List<VideAttachment>? attachments;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  const VideMessage({required this.text, this.attachments, this.metadata});

  /// Shorthand for a text-only message.
  const VideMessage.text(String text)
    : text = text,
      attachments = null,
      metadata = null;
}
