import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  final String text;
  final List<Attachment>? attachments;
  final Map<String, dynamic>? metadata;

  const Message({required this.text, this.attachments, this.metadata});

  const Message.text(String text)
    : text = text,
      attachments = null,
      metadata = null;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  Map<String, dynamic> toClaudeJson() {
    return {
      'type': 'user',
      'message': {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text},
          if (attachments != null) ...attachments!.map((a) => a.toClaudeJson()),
        ],
      },
    };
  }
}

@JsonSerializable()
class Attachment {
  final String type;
  final String? path;
  final String? content;
  final String? mimeType;

  const Attachment({
    required this.type,
    this.path,
    this.content,
    this.mimeType,
  });

  factory Attachment.file(String path) => Attachment(type: 'file', path: path);

  factory Attachment.image(String path) {
    final mimeType = _detectMediaType(path);
    return Attachment(type: 'image', path: path, mimeType: mimeType);
  }

  factory Attachment.imageBase64(String base64Data, String mediaType) =>
      Attachment(type: 'image', content: base64Data, mimeType: mediaType);

  factory Attachment.documentText({required String text, String? title}) =>
      Attachment(
        type: 'document',
        content: text,
        mimeType: 'text/plain',
        path: title, // Reuse path field to store title
      );

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);

  Map<String, dynamic> toJson() => _$AttachmentToJson(this);

  Map<String, dynamic> toClaudeJson() {
    if (type == 'image') {
      String base64Data;

      // If content is provided, use it directly
      if (content != null) {
        base64Data = content!;
      }
      // If path is provided, read the file and encode it
      else if (path != null) {
        final file = File(path!);
        final bytes = file.readAsBytesSync();
        base64Data = base64Encode(bytes);
      } else {
        throw ArgumentError(
          'Either content or path must be provided for image attachment',
        );
      }

      return {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType ?? 'image/jpeg',
          'data': base64Data,
        },
      };
    }

    if (type == 'document') {
      if (content == null) {
        throw ArgumentError('Content must be provided for document attachment');
      }

      final result = <String, dynamic>{
        'type': 'document',
        'source': {
          'type': 'text',
          'media_type': mimeType ?? 'text/plain',
          'data': content!,
        },
      };

      // Add title if provided (stored in path field)
      if (path != null) {
        result['title'] = path;
      }

      return result;
    }

    // For non-image, non-document types, return the standard JSON representation
    return toJson();
  }

  static String _detectMediaType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
