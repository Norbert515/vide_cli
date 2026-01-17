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
