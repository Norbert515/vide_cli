import 'dart:async';

import '../models/agent_conversation.dart';
import '../models/agent_init_data.dart';
import '../models/agent_message.dart';
import '../models/agent_response.dart';
import '../models/agent_status.dart';

/// Generic interface for interacting with an AI coding agent.
///
/// This is the common contract that consumers (like vide_core) depend on.
/// Each agent SDK (claude_sdk, codex_sdk) provides a bridge implementation
/// that wraps their SDK-specific client and maps types into this interface.
///
/// Extended capabilities (model switching, permission modes, etc.) are
/// expressed as separate interfaces that the bridge may also implement.
/// Use `if (client is ModelConfigurable)` to check for support.
abstract class AgentClient {
  // ── Streams ──────────────────────────────────────────────

  /// Stream of conversation state changes.
  /// Emits whenever messages are added or updated (including streaming deltas).
  Stream<AgentConversation> get conversation;

  /// Emits when an agent turn completes (assistant finishes responding).
  Stream<void> get onTurnComplete;

  /// Stream of processing status updates (thinking, responding, etc.)
  Stream<AgentProcessingStatus> get statusStream;

  /// Stream of initialization data (model name, tools, etc.)
  /// Emits when the agent CLI sends its init message.
  Stream<AgentInitData> get initDataStream;

  /// Stream of queued message text changes.
  /// Emits the queued text, or null when queue is cleared.
  Stream<String?> get queuedMessage;

  // ── Current state ────────────────────────────────────────

  /// The current conversation snapshot.
  AgentConversation get currentConversation;

  /// The most recent processing status.
  AgentProcessingStatus get currentStatus;

  /// The most recent initialization data, or null if not yet received.
  AgentInitData? get initData;

  /// The current queued message text, or null if no message is queued.
  String? get currentQueuedMessage;

  /// The session ID for this client instance.
  String get sessionId;

  /// The working directory for this agent.
  String get workingDirectory;

  /// Future that completes when the client has finished initializing.
  Future<void> get initialized;

  // ── Actions ──────────────────────────────────────────────

  /// Send a message to the agent.
  void sendMessage(AgentMessage message);

  /// Abort the current operation.
  Future<void> abort();

  /// Close the client and release all resources.
  Future<void> close();

  /// Clear the conversation history, starting fresh.
  Future<void> clearConversation();

  /// Clear any queued message without sending it.
  void clearQueuedMessage();

  /// Inject a synthetic tool result into the conversation.
  /// Used to mark a pending tool invocation as failed (e.g., when
  /// permission is denied).
  void injectToolResult(AgentToolResultResponse toolResult);

  /// Get a registered MCP server by name and type.
  /// Returns null if not found.
  T? getMcpServer<T>(String name);
}
