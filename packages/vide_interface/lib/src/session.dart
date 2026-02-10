/// Abstract session interface for the Vide ecosystem.
///
/// Both local (in-process) and remote (WebSocket) sessions implement this
/// interface, providing a transport-independent API for interacting with
/// agent networks.
library;

import 'dart:async';

import 'events/vide_event.dart';
import 'models/vide_agent.dart';
import 'models/vide_conversation.dart';
import 'models/vide_message.dart';
import 'models/vide_permission.dart';
import 'state/conversation_state.dart';

/// An active session with a network of agents.
///
/// Use this interface to:
/// - Listen to events from all agents via [events]
/// - Send messages to agents via [sendMessage]
/// - Handle permissions via [respondToPermission]
/// - Manage agent lifecycle via [spawnAgent], [terminateAgent], [abort]
///
/// Example:
/// ```dart
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent e:
///       stdout.write(e.content);
///     case ToolUseEvent e:
///       print('Tool: ${e.toolName}');
///     case PermissionRequestEvent e:
///       session.respondToPermission(e.requestId, allow: true);
///   }
/// });
/// ```
abstract interface class VideSession {
  /// Unique identifier for this session.
  String get id;

  /// Get the conversation state manager for this session.
  ConversationStateManager get conversationState;

  /// Stream of all events from all agents in the session.
  Stream<VideEvent> get events;

  /// Current agents in the session (immutable snapshot).
  List<VideAgent> get agents;

  /// Stream that emits the current agents list whenever it changes.
  Stream<List<VideAgent>> get agentsStream;

  /// The main agent (first agent in the network).
  VideAgent? get mainAgent;

  /// List of agent IDs in the session.
  List<String> get agentIds;

  /// Whether any agent in the session is currently processing.
  bool get isProcessing;

  /// The effective working directory for this session.
  String get workingDirectory;

  /// Stream that emits the current working directory whenever it changes.
  Stream<String> get workingDirectoryStream;

  /// The goal/task name for this session.
  String get goal;

  /// Stream that emits the current goal whenever it changes.
  Stream<String> get goalStream;

  /// Stream that emits when session transport connectivity changes.
  Stream<bool> get connectionStateStream;

  /// The team name for this session (e.g., 'vide', 'enterprise').
  String get team;

  // ============================================================
  // Messaging
  // ============================================================

  /// Send a message to an agent.
  ///
  /// If [agentId] is not specified, the message is sent to the main agent.
  ///
  /// **Contract:** Implementations must add the user message to
  /// [conversationState] synchronously before returning. This enables
  /// optimistic UI updates — the message appears immediately regardless
  /// of whether the backend has acknowledged it. Remote implementations
  /// handle deduplication internally when the server echoes the message.
  void sendMessage(VideMessage message, {String? agentId});

  // ============================================================
  // Permission handling
  // ============================================================

  /// Respond to a permission request.
  ///
  /// If [remember] is true and [allow] is true, the permission pattern will be
  /// stored so the same operation is auto-approved in the future. Write
  /// operations go to the session cache; non-write operations go to the
  /// persistent allow list. [patternOverride] replaces the inferred pattern.
  void respondToPermission(
    String requestId, {
    required bool allow,
    String? message,
    bool remember = false,
    String? patternOverride,
  });

  /// Respond to an AskUserQuestion request.
  void respondToAskUserQuestion(
    String requestId, {
    required Map<String, String> answers,
  });

  /// Respond to a plan approval request (ExitPlanMode).
  ///
  /// [action] must be 'accept' or 'reject'.
  /// When rejecting, [feedback] is sent back to Claude as a deny message
  /// so it can revise the plan.
  void respondToPlanApproval(
    String requestId, {
    required String action,
    String? feedback,
  });

  /// Add a pattern to the session permission cache.
  Future<void> addSessionPermissionPattern(String pattern);

  /// Check if a tool is allowed by the session cache.
  Future<bool> isAllowedBySessionCache(
    String toolName,
    Map<String, dynamic> input,
  );

  /// Clear the session permission cache.
  Future<void> clearSessionPermissionCache();

  // ============================================================
  // Agent lifecycle
  // ============================================================

  /// Abort all agents in the session.
  Future<void> abort();

  /// Abort a specific agent.
  Future<void> abortAgent(String agentId);

  /// Terminate an agent and remove it from the network.
  Future<void> terminateAgent(
    String agentId, {
    required String terminatedBy,
    String? reason,
  });

  /// Spawn a new agent by agent type.
  Future<String> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required String spawnedBy,
  });

  /// Fork an agent to create a new conversation branch.
  Future<String> forkAgent(String agentId, {String? name});

  // ============================================================
  // Conversation management
  // ============================================================

  /// Clear the conversation for an agent (resets context).
  Future<void> clearConversation({String? agentId});

  /// Get the current conversation for an agent.
  VideConversation? getConversation(String agentId);

  /// Stream of conversation updates for an agent.
  Stream<VideConversation> conversationStream(String agentId);

  /// Update token/cost statistics for an agent.
  void updateAgentTokenStats(
    String agentId, {
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalCacheReadInputTokens,
    required int totalCacheCreationInputTokens,
    required double totalCostUsd,
  });

  // ============================================================
  // Queued messages
  // ============================================================

  /// Get the queued message for an agent, if any.
  Future<String?> getQueuedMessage(String agentId);

  /// Stream of queued message changes for an agent.
  Stream<String?> queuedMessageStream(String agentId);

  /// Clear the queued message for an agent.
  Future<void> clearQueuedMessage(String agentId);

  // ============================================================
  // Model info
  // ============================================================

  /// Get the model name for an agent.
  Future<String?> getModel(String agentId);

  /// Stream of model changes for an agent.
  Stream<String?> modelStream(String agentId);

  // ============================================================
  // Worktree management
  // ============================================================

  /// Set the working directory (worktree path) for this session.
  Future<void> setWorktreePath(String? path);

  // ============================================================
  // Permission callback (for internal use by implementations)
  // ============================================================

  /// Creates a permission callback for tool permission checks.
  VideCanUseToolCallback createPermissionCallback({
    required String agentId,
    required String? agentName,
    required String? agentType,
    required String cwd,
    String? permissionMode,
  });

  // ============================================================
  // Lifecycle
  // ============================================================

  /// Dispose the session and release resources.
  Future<void> dispose({bool fireEndTrigger = true});
}
