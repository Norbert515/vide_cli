import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// The role of a message sender.
@JsonEnum(fieldRename: FieldRename.kebab)
enum MessageRole {
  user,
  assistant,
}

/// Represents a chat message in the session.
@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    @JsonKey(name: 'event-id') required String eventId,
    required MessageRole role,
    required String content,
    @JsonKey(name: 'agent-id') required String agentId,
    @JsonKey(name: 'agent-type') required String agentType,
    @JsonKey(name: 'agent-name') String? agentName,
    required DateTime timestamp,
    @JsonKey(name: 'is-streaming') @Default(false) bool isStreaming,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
