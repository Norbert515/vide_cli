/// Lightweight client for connecting to remote vide servers.
///
/// This package provides both a high-level [VideClient] for easy server
/// interaction and a [WebSocketSessionTransport] that implements the
/// [SessionTransport] interface from vide_interface.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:vide_client/vide_client.dart';
///
/// final client = VideClient(Uri.parse('http://localhost:8080'));
///
/// // Create a new session
/// final sessionInfo = await client.createSession(
///   initialMessage: 'Hello!',
///   workingDirectory: '/path/to/project',
/// );
///
/// // Connect to the session
/// final transport = await client.connect(sessionInfo.sessionId);
///
/// // Listen for events
/// transport.events.listen((event) {
///   switch (event) {
///     case MessageEvent(:final content):
///       print('Message: $content');
///     case ToolUseEvent(:final toolName):
///       print('Tool: $toolName');
///     // ...
///   }
/// });
///
/// // Send a message
/// transport.send(SendUserMessage(content: 'Do something'));
///
/// // Close when done
/// await transport.close();
/// ```
library vide_client;

// Re-export vide_interface types used by client code
// Note: We explicitly list types to avoid conflicts with vide_core's AgentStatus
export 'package:vide_interface/vide_interface.dart'
    show
        // Session transport
        SessionTransport,
        ConnectionState,
        // Events
        SessionEvent,
        SequencedEvent,
        ConnectedEvent,
        MessageEvent,
        ToolUseEvent,
        ToolResultEvent,
        PermissionRequestEvent,
        AgentSpawnedEvent,
        AgentTerminatedEvent,
        AgentStatusEvent,
        ErrorEvent,
        ClientJoinedEvent,
        ClientLeftEvent,
        TurnCompleteEvent,
        PermissionTimeoutEvent,
        AbortedEvent,
        // Client messages
        ClientMessage,
        SendUserMessage,
        PermissionResponse,
        AbortRequest,
        // Models (excluding AgentStatus to avoid conflict with vide_core)
        SessionInfo,
        AgentInfo,
        ServerInfo,
        ConnectedClient,
        ClientPermission;

export 'src/vide_client.dart' show VideClient, VideClientException;
export 'src/websocket_transport.dart' show WebSocketSessionTransport, VideTransportException;
