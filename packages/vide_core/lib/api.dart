/// Public API for vide_core.
///
/// This is the recommended way to use vide_core for new consumers.
/// It provides a clean, simple interface to create and manage multi-agent
/// sessions without exposing internal implementation details.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:vide_core/api.dart';
///
/// void main() async {
///   // Create VideCore instance
///   final core = VideCore(VideCoreConfig());
///
///   // Start a new session
///   final session = await core.startSession(VideSessionConfig(
///     workingDirectory: '/path/to/project',
///     initialMessage: 'Help me fix the bug in auth.dart',
///   ));
///
///   // Listen to events from all agents
///   session.events.listen((event) {
///     switch (event) {
///       case MessageEvent e:
///         stdout.write(e.content);
///       case ToolUseEvent e:
///         print('[Tool: ${e.toolName}]');
///       case ToolResultEvent e:
///         if (e.isError) print('[Error: ${e.result}]');
///       case TurnCompleteEvent e:
///         print('\n--- Turn complete ---');
///       case AgentSpawnedEvent e:
///         print('[Agent spawned: ${e.agentName}]');
///       case AgentTerminatedEvent e:
///         print('[Agent terminated: ${e.agentId}]');
///       case PermissionRequestEvent e:
///         // Handle permission request
///         session.respondToPermission(e.requestId, allow: true);
///       case StatusEvent e:
///         // Agent status changed
///       case ErrorEvent e:
///         print('[Error: ${e.message}]');
///     }
///   });
///
///   // Send follow-up messages
///   session.sendMessage('Can you also add tests?');
///
///   // Clean up when done
///   await session.dispose();
///   core.dispose();
/// }
/// ```
///
/// ## Key Classes
///
/// - [VideCore] - The main entry point. Create one instance per application.
/// - [VideSession] - An active session with a network of agents.
/// - [VideEvent] - Sealed class hierarchy for all event types.
/// - [VideAgent] - Immutable snapshot of an agent's state.
/// - [VideCoreConfig] - Configuration for creating VideCore.
/// - [VideSessionConfig] - Configuration for starting a session.
/// - [VideSessionInfo] - Summary info for listing sessions.
/// - [VideEmbeddedServer] - Lightweight HTTP/WebSocket server for remote access.
///
/// ## Event Types
///
/// - [MessageEvent] - Text content from agents (streams as partial chunks).
/// - [ToolUseEvent] - Agent is invoking a tool.
/// - [ToolResultEvent] - Tool execution completed.
/// - [StatusEvent] - Agent status changed (working, idle, etc.).
/// - [TurnCompleteEvent] - Agent completed its turn.
/// - [AgentSpawnedEvent] - New agent joined the network.
/// - [AgentTerminatedEvent] - Agent was removed from the network.
/// - [PermissionRequestEvent] - Permission needed for a tool.
/// - [ErrorEvent] - An error occurred.
library vide_core.api;

export 'api/vide_core.dart' show VideCore;
export 'api/vide_session.dart' show VideSession;
export 'api/vide_event.dart';
export 'api/vide_agent.dart';
export 'api/vide_config.dart';
export 'api/embedded_server.dart' show VideEmbeddedServer;
export 'api/conversation_state.dart';

// Common type aliases
export 'models/agent_id.dart' show AgentId;

// Initial client for pre-warming and MCP status
export 'services/initial_claude_client.dart' show InitialClaudeClient;

// Network types
export 'models/agent_network.dart' show AgentNetwork;
export 'models/agent_id.dart' show AgentNetworkId;
export 'services/agent_network_manager.dart'
    show AgentNetworkState, agentNetworkManagerProvider, AgentNetworkManager;

// Agent metadata (for running agents bar)
export 'models/agent_metadata.dart' show AgentMetadata;

// Config manager
export 'services/vide_config_manager.dart'
    show VideConfigManager, videConfigManagerProvider;
export 'models/vide_global_settings.dart' show VideGlobalSettings;

// Memory service
export 'services/memory_service.dart' show MemoryService, memoryServiceProvider;
export 'models/memory_entry.dart' show MemoryEntry;

// Permission utilities (for TUI permission dialog)
export 'services/permissions/pattern_inference.dart' show PatternInference;
export 'services/permissions/tool_input.dart'
    show
        ToolInput,
        BashToolInput,
        ReadToolInput,
        WriteToolInput,
        EditToolInput,
        MultiEditToolInput,
        EditOperation,
        WebFetchToolInput,
        WebSearchToolInput,
        GrepToolInput,
        GlobToolInput,
        UnknownToolInput;

// Ask user question MCP
export 'mcp/ask_user_question/ask_user_question_service.dart'
    show AskUserQuestionService, askUserQuestionServiceProvider;
export 'mcp/ask_user_question/ask_user_question_types.dart'
    show
        AskUserQuestion,
        AskUserQuestionOption,
        AskUserQuestionRequest,
        AskUserQuestionResponse;

// Project detection
export 'utils/project_detector.dart'
    show ProjectDetector, ProjectType, projecTypeProvider;

// Permission callback infrastructure
export 'services/permission_provider.dart'
    show
        PermissionCallbackContext,
        CanUseToolCallbackFactory,
        canUseToolCallbackFactoryProvider;

// Analytics
export 'services/posthog_service.dart' show PostHogService;

// Agent status
export 'models/agent_status.dart' show AgentStatus, AgentStatusExtension;
export 'state/agent_status_manager.dart'
    show agentStatusProvider, AgentStatusNotifier;

// Claude status (from ClaudeManager)
export 'services/claude_manager.dart' show claudeStatusProvider;

// Network persistence
export 'services/agent_network_persistence_manager.dart'
    show AgentNetworkPersistenceManager, agentNetworkPersistenceManagerProvider;

// Permission checker (for TUI permission service)
export 'services/permissions/permission_checker.dart'
    show
        PermissionChecker,
        PermissionCheckerConfig,
        AskUserBehavior,
        PermissionCheckResult,
        PermissionAllow,
        PermissionDeny,
        PermissionAskUser;

// Claude SDK types for permission service and general use
// (Consolidated from multiple export statements)
export 'package:claude_sdk/claude_sdk.dart'
    show
        // Core types
        Conversation,
        ConversationMessage,
        MessageRole,
        McpServerBase,
        McpStatusResponse,
        McpServerStatusInfo,
        Message,
        Attachment,
        // Status
        ClaudeStatus,
        // Permission types
        ToolPermissionContext,
        PermissionResult,
        PermissionResultAllow,
        PermissionResultDeny,
        ClaudeSettingsManager;

// Working directory provider
export 'utils/working_dir_provider.dart' show workingDirProvider;

// Auto-update service
export 'services/auto_update_service.dart'
    show autoUpdateServiceProvider, AutoUpdateService, UpdateStatus, UpdateState, UpdateInfo;

// Git providers, client, and models
export 'mcp/git/git_providers.dart' show gitStatusStreamProvider;
export 'mcp/git/git_client.dart' show GitClient;
export 'mcp/git/git_models.dart'
    show GitStatus, GitBranch, GitWorktree, GitCommit, GitRepository;
