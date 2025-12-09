// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  text: json['text'] as String,
  attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'text': instance.text,
  'attachments': instance.attachments,
  'metadata': instance.metadata,
};

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
  type: json['type'] as String,
  path: json['path'] as String?,
  content: json['content'] as String?,
  mimeType: json['mimeType'] as String?,
);

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{
      'type': instance.type,
      'path': instance.path,
      'content': instance.content,
      'mimeType': instance.mimeType,
    };
