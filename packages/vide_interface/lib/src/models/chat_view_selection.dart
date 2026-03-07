/// Typed selection state for the chat view.
library;

/// What the user is currently viewing in the chat UI.
sealed class ChatViewSelection {
  const ChatViewSelection();
}

/// Viewing the channel overview (all cross-agent messages).
final class ChannelOverview extends ChatViewSelection {
  const ChannelOverview();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChannelOverview;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Viewing a specific agent's conversation.
final class AgentView extends ChatViewSelection {
  final String agentId;
  const AgentView(this.agentId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AgentView && agentId == other.agentId;

  @override
  int get hashCode => agentId.hashCode;
}
