/// Shared enums for the Vide ecosystem.
library;

/// Role of a message sender.
enum MessageRole {
  user,
  assistant;

  static MessageRole fromString(String value) => switch (value) {
    'user' => MessageRole.user,
    'assistant' => MessageRole.assistant,
    _ => MessageRole.assistant,
  };

  String toWireString() => switch (this) {
    MessageRole.user => 'user',
    MessageRole.assistant => 'assistant',
  };
}
