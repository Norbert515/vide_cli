/// A message to send to an AI coding agent.
class AgentMessage {
  /// The text content of the message.
  final String text;

  /// Optional file attachments (images, documents, files).
  final List<AgentAttachment>? attachments;

  /// Optional metadata for the message.
  final Map<String, dynamic>? metadata;

  const AgentMessage({required this.text, this.attachments, this.metadata});

  /// Convenience constructor for text-only messages.
  const AgentMessage.text(String text)
    : text = text,
      attachments = null,
      metadata = null;
}

/// An attachment to include with an [AgentMessage].
class AgentAttachment {
  /// The type of attachment: 'file', 'image', or 'document'.
  final String type;

  /// File path (for file/image types, also used as title for documents).
  final String? path;

  /// Content data (base64 for images, text for documents).
  final String? content;

  /// MIME type (e.g., 'image/png', 'text/plain').
  final String? mimeType;

  const AgentAttachment({
    required this.type,
    this.path,
    this.content,
    this.mimeType,
  });

  /// Create a file attachment from a path.
  const AgentAttachment.file(String path)
    : type = 'file',
      path = path,
      content = null,
      mimeType = null;

  /// Create an image attachment from a path.
  const AgentAttachment.image(String path, {String? mimeType})
    : type = 'image',
      path = path,
      content = null,
      mimeType = mimeType;

  /// Create an image attachment from base64 data.
  const AgentAttachment.imageBase64(String base64Data, String mediaType)
    : type = 'image',
      path = null,
      content = base64Data,
      mimeType = mediaType;

  /// Create a text document attachment.
  const AgentAttachment.documentText({required String text, String? title})
    : type = 'document',
      path = title,
      content = text,
      mimeType = 'text/plain';
}
