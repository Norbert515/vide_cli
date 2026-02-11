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

/// Immutable snapshot of session state.
///
/// All observable session-level metadata is captured here. Use [copyWith]
/// to derive a new state with selected fields changed.
///
/// Conversation content is available via [agentConversationStates] as a
/// snapshot reference. For real-time streaming updates, consumers should
/// use [ConversationStateManager.onStateChanged] directly.
class VideState {
  /// Unique identifier for this session.
  final String id;

  /// Current agents in the session (immutable snapshot).
  final List<VideAgent> agents;

  /// Per-agent conversation state snapshots.
  final List<AgentConversationState> agentConversationStates;

  /// The team name for this session (e.g., 'vide', 'enterprise').
  final String team;

  /// The goal/task name for this session.
  final String goal;

  /// The effective working directory for this session.
  final String workingDirectory;

  /// Whether any agent in the session is currently processing.
  final bool isProcessing;

  const VideState({
    required this.id,
    this.agents = const [],
    this.agentConversationStates = const [],
    this.team = 'vide',
    this.goal = 'Session',
    this.workingDirectory = '',
    this.isProcessing = false,
  });

  /// List of agent IDs in the session.
  List<String> get agentIds => agents.map((agent) => agent.id).toList();

  /// The main agent (first agent in the network).
  VideAgent? get mainAgent => agents.firstOrNull;

  /// Returns a copy with the given fields replaced.
  VideState copyWith({
    String? id,
    List<VideAgent>? agents,
    List<AgentConversationState>? agentConversationStates,
    String? team,
    String? goal,
    String? workingDirectory,
    bool? isProcessing,
  }) {
    return VideState(
      id: id ?? this.id,
      agents: agents ?? this.agents,
      agentConversationStates:
          agentConversationStates ?? this.agentConversationStates,
      team: team ?? this.team,
      goal: goal ?? this.goal,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          team == other.team &&
          goal == other.goal &&
          workingDirectory == other.workingDirectory &&
          isProcessing == other.isProcessing &&
          _listEquals(agents, other.agents) &&
          _listEquals(
            agentConversationStates,
            other.agentConversationStates,
          );

  @override
  int get hashCode => Object.hash(
    id,
    team,
    goal,
    workingDirectory,
    isProcessing,
    Object.hashAll(agents),
  );

  @override
  String toString() =>
      'VideState(id: $id, agents: ${agents.length}, goal: $goal, team: $team)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

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
abstract class VideSession {
  /// Get the conversation state manager for this session.
  ConversationStateManager get conversationState;

  /// The current immutable session state snapshot.
  VideState get state;

  /// Stream of state changes (agents, goal, team, workingDirectory, etc.).
  Stream<VideState> get stateStream;

  /// Unique identifier for this session.
  String get id;

  /// Stream of all events from all agents in the session.
  Stream<VideEvent> get events;

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
  void respondToAskUserQuestion(String requestId, {required Map<String, String> answers});

  /// Respond to a plan approval request (ExitPlanMode).
  ///
  /// [action] must be 'accept' or 'reject'.
  /// When rejecting, [feedback] is sent back to Claude as a deny message
  /// so it can revise the plan.
  void respondToPlanApproval(String requestId, {required String action, String? feedback});

  /// Add a pattern to the session permission cache.
  Future<void> addSessionPermissionPattern(String pattern);

  /// Check if a tool is allowed by the session cache.
  Future<bool> isAllowedBySessionCache(String toolName, Map<String, dynamic> input);

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
  Future<void> terminateAgent(String agentId, {required String terminatedBy, String? reason});

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
