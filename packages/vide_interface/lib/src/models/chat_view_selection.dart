/// Typed selection state for the chat view.
library;

/// What the user is currently viewing in the chat UI.
sealed class ChatViewSelection {
  const ChatViewSelection();
}

/// Viewing the channel overview (all cross-agent messages).
final class ChannelOverview extends ChatViewSelection {
  const ChannelOverview();
}

/// Viewing a specific agent's conversation.
final class AgentView extends ChatViewSelection {
  final String agentId;
  const AgentView(this.agentId);
}
