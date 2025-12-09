/// Status of an agent in the network.
///
/// This is set explicitly by the agent via the `setAgentStatus` MCP tool
/// to communicate its current state to the user.
enum AgentStatus {
  /// Agent is actively processing/working on a task.
  /// UI: Animated spinner character.
  working,

  /// Agent is waiting for another agent to respond.
  /// UI: Waiting indicator (e.g., ⏳).
  waitingForAgent,

  /// Agent is waiting for user input/approval.
  /// UI: User input indicator (e.g., ?).
  waitingForUser,

  /// Agent has finished its work and is not waiting for anything.
  /// UI: Done indicator (e.g., ✓).
  idle,
}

extension AgentStatusExtension on AgentStatus {
  /// Parse a string to AgentStatus, returns null if invalid.
  static AgentStatus? fromString(String value) {
    return switch (value) {
      'working' => AgentStatus.working,
      'waitingForAgent' => AgentStatus.waitingForAgent,
      'waitingForUser' => AgentStatus.waitingForUser,
      'idle' => AgentStatus.idle,
      _ => null,
    };
  }

  /// Convert to string for serialization.
  String toStringValue() {
    return switch (this) {
      AgentStatus.working => 'working',
      AgentStatus.waitingForAgent => 'waitingForAgent',
      AgentStatus.waitingForUser => 'waitingForUser',
      AgentStatus.idle => 'idle',
    };
  }
}
