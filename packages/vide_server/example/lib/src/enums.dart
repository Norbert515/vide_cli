/// Enums for vide_server WebSocket events.

/// Role of a message sender.
enum MessageRole {
  user,
  assistant;

  static MessageRole fromString(String value) => switch (value) {
        'user' => MessageRole.user,
        'assistant' => MessageRole.assistant,
        _ => MessageRole.assistant,
      };
}

/// Status of an agent.
enum AgentStatus {
  working,
  waitingForAgent,
  waitingForUser,
  idle;

  static AgentStatus fromString(String? value) => switch (value) {
        'working' => AgentStatus.working,
        'waiting-for-agent' => AgentStatus.waitingForAgent,
        'waiting-for-user' => AgentStatus.waitingForUser,
        'idle' => AgentStatus.idle,
        _ => AgentStatus.idle,
      };
}
