/// Re-exports event types from vide_interface.
///
/// These types used to live here but have been moved to vide_interface
/// for sharing across packages.
library;

export 'package:vide_interface/vide_interface.dart'
    show
        VideEvent,
        MessageEvent,
        ToolUseEvent,
        ToolResultEvent,
        StatusEvent,
        TurnCompleteEvent,
        AgentSpawnedEvent,
        AgentTerminatedEvent,
        PermissionRequestEvent,
        PermissionTimeoutEvent,
        AskUserQuestionEvent,
        AskUserQuestionData,
        AskUserQuestionOptionData,
        TaskNameChangedEvent,
        AbortedEvent,
        ErrorEvent,
        CommandResultEvent,
        ConnectedEvent,
        HistoryEvent,
        UnknownEvent;
