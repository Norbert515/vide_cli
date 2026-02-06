/// Re-exports conversation state types from vide_interface.
///
/// These types used to live here but have been moved to vide_interface
/// for sharing across packages.
library;

export 'package:vide_interface/vide_interface.dart'
    show
        ConversationStateManager,
        AgentConversationState,
        ConversationContent,
        TextContent,
        ToolContent,
        ConversationEntry;
