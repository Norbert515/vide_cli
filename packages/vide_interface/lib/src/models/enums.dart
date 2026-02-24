/// Shared enums for the Vide ecosystem.
library;

/// Role of a message sender.
enum MessageRole {
  user,
  assistant,
  system;

  static MessageRole fromString(String value) => switch (value) {
    'user' => MessageRole.user,
    'assistant' => MessageRole.assistant,
    'system' => MessageRole.system,
    _ => MessageRole.assistant,
  };

  String toWireString() => switch (this) {
    MessageRole.user => 'user',
    MessageRole.assistant => 'assistant',
    MessageRole.system => 'system',
  };
}
