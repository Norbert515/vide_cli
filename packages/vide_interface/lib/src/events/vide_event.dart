/// Unified event hierarchy for the Vide ecosystem.
///
/// This merges the previously separate event types from vide_core (business
/// events with toJson) and vide_client (wire events with fromJson) into a
/// single canonical hierarchy with both serialization directions.
library;

import '../models/vide_agent.dart';
import '../models/vide_message.dart';
import 'agent_info.dart';

/// Base class for all session events.
///
/// Use pattern matching to handle different event types:
/// ```dart
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent e:
///       stdout.write(e.content);
///     case ToolUseEvent e:
///       print('Tool: ${e.toolName}');
///     case PermissionRequestEvent e:
///       // Handle permission
///   }
/// });
/// ```
sealed class VideEvent {
  /// Wire-format sequence number (added by transport layer).
  final int? seq;

  /// ID of the agent that produced this event.
  final String agentId;

  /// Type of the agent (e.g., "main", "implementation").
  final String agentType;

  /// Human-readable agent name (e.g., "Main", "Bug Fix").
  final String? agentName;

  /// Current task name for the agent.
  final String? taskName;

  /// When this event occurred.
  final DateTime timestamp;

  VideEvent({
    this.seq,
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Wire-format event type string (e.g., 'message', 'tool-use', 'done').
  String get wireType;

  /// Event-specific data fields for the JSON 'data' key.
  Map<String, dynamic> dataFields();

  /// Extra top-level fields merged into the JSON (e.g., 'event-id', 'is-partial').
  Map<String, dynamic> topLevelFields() => const {};

  /// Serialize this event to the wire-format JSON used by the server API.
  ///
  /// Transport layers should add 'seq' and 'event-id' (if not already present)
  /// before sending.
  Map<String, dynamic> toJson() => {
    'type': wireType,
    'agent-id': agentId,
    'agent-type': agentType,
    'agent-name': agentName,
    'task-name': taskName,
    'timestamp': timestamp.toIso8601String(),
    'data': dataFields(),
    ...topLevelFields(),
  };

  /// Parse a JSON event from the wire format.
  factory VideEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final timestamp =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final seq = json['seq'] as int?;
    final eventId = json['event-id'] as String?;

    // Extract agent info from top-level fields
    final agentId = json['agent-id'] as String? ?? '';
    final agentType = json['agent-type'] as String? ?? '';
    final agentName = json['agent-name'] as String?;
    final taskName = json['task-name'] as String?;

    final data = json['data'] as Map<String, dynamic>?;

    return switch (type) {
      'connected' => ConnectedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        sessionId: json['session-id'] as String,
        mainAgentId: json['main-agent-id'] as String,
        lastSeq: json['last-seq'] as int? ?? 0,
        agents:
            (json['agents'] as List<dynamic>?)
                ?.map((a) => AgentInfo.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        metadata: Map<String, dynamic>.from(
          json['metadata'] as Map<String, dynamic>? ?? const {},
        ),
      ),
      'history' => HistoryEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        lastSeq: json['last-seq'] as int? ?? 0,
        events: data?['events'] as List<dynamic>? ?? [],
      ),
      'message' => MessageEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        eventId: eventId ?? '',
        role: data?['role'] as String? ?? 'assistant',
        content: data?['content'] as String? ?? '',
        isPartial: json['is-partial'] as bool? ?? false,
        attachments: _parseAttachments(data?['attachments']),
      ),
      'status' => StatusEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        status: VideAgentStatus.fromWireString(data?['status'] as String?),
      ),
      'tool-use' => ToolUseEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        toolUseId: data!['tool-use-id'] as String,
        toolName: data['tool-name'] as String,
        toolInput: data['tool-input'] as Map<String, dynamic>? ?? {},
      ),
      'tool-result' => ToolResultEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        toolUseId: data!['tool-use-id'] as String,
        toolName: data['tool-name'] as String,
        result: data['result'] is String
            ? data['result'] as String
            : (data['result']?.toString() ?? ''),
        isError: data['is-error'] as bool? ?? false,
      ),
      'permission-request' => PermissionRequestEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data!['request-id'] as String,
        toolName:
            (data['tool'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        toolInput:
            (data['tool'] as Map<String, dynamic>?)?['input']
                as Map<String, dynamic>? ??
            {},
        inferredPattern: _extractInferredPattern(data['tool']),
      ),
      'permission-resolved' => PermissionResolvedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data!['request-id'] as String,
        allow: data['allow'] as bool? ?? false,
        message: data['message'] as String?,
      ),
      'ask-user-question' => AskUserQuestionEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data?['request-id'] as String? ?? '',
        questions: _parseQuestions(data?['questions']),
      ),
      'ask-user-question-resolved' => AskUserQuestionResolvedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data?['request-id'] as String? ?? '',
        answers: (data?['answers'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ?? {},
      ),
      'task-name-changed' => TaskNameChangedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        newGoal: data?['new-goal'] as String? ?? '',
        previousGoal: data?['previous-goal'] as String?,
      ),
      'agent-spawned' => AgentSpawnedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        spawnedBy: data?['spawned-by'] as String? ?? '',
      ),
      'agent-terminated' => AgentTerminatedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        terminatedBy: data?['terminated-by'] as String?,
        reason: data?['reason'] as String?,
      ),
      'done' => TurnCompleteEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        reason: data?['reason'] as String? ?? 'complete',
        totalInputTokens: data?['total-input-tokens'] as int? ?? 0,
        totalOutputTokens: data?['total-output-tokens'] as int? ?? 0,
        totalCacheReadInputTokens:
            data?['total-cache-read-input-tokens'] as int? ?? 0,
        totalCacheCreationInputTokens:
            data?['total-cache-creation-input-tokens'] as int? ?? 0,
        totalCostUsd: (data?['total-cost-usd'] as num?)?.toDouble() ?? 0.0,
        currentContextInputTokens:
            data?['current-context-input-tokens'] as int? ?? 0,
        currentContextCacheReadTokens:
            data?['current-context-cache-read-tokens'] as int? ?? 0,
        currentContextCacheCreationTokens:
            data?['current-context-cache-creation-tokens'] as int? ?? 0,
      ),
      'aborted' => AbortedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
      ),
      'error' => ErrorEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        message: data!['message'] as String,
        code: data['code'] as String?,
      ),
      'command-result' => CommandResultEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data?['request-id'] as String? ?? '',
        command: data?['command'] as String? ?? '',
        success: data?['success'] as bool? ?? false,
        result: (data?['result'] is Map)
            ? Map<String, dynamic>.from(data?['result'] as Map)
            : null,
        errorMessage: (data?['error'] is Map)
            ? (data?['error'] as Map)['message'] as String?
            : null,
        errorCode: (data?['error'] is Map)
            ? (data?['error'] as Map)['code'] as String?
            : null,
      ),
      'plan-approval-request' => PlanApprovalRequestEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data?['request-id'] as String? ?? '',
        planContent: data?['plan-content'] as String? ?? '',
        allowedPrompts: (data?['allowed-prompts'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      ),
      'plan-approval-resolved' => PlanApprovalResolvedEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        requestId: data?['request-id'] as String? ?? '',
        action: data?['action'] as String? ?? '',
        feedback: data?['feedback'] as String?,
      ),
      _ => UnknownEvent(
        seq: seq,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
        timestamp: timestamp,
        type: type,
        rawData: json,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Event subtypes
// ---------------------------------------------------------------------------

/// WebSocket connection established.
final class ConnectedEvent extends VideEvent {
  final String sessionId;
  final String mainAgentId;
  final int lastSeq;
  final List<AgentInfo> agents;
  final Map<String, dynamic> metadata;

  ConnectedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.sessionId,
    required this.mainAgentId,
    required this.lastSeq,
    required this.agents,
    required this.metadata,
  });

  @override
  String get wireType => 'connected';

  @override
  Map<String, dynamic> dataFields() => {};

  @override
  Map<String, dynamic> topLevelFields() => {
    'session-id': sessionId,
    'main-agent-id': mainAgentId,
    'last-seq': lastSeq,
    'agents': agents.map((a) => a.toJson()).toList(),
    'metadata': metadata,
  };
}

/// Session history for reconnection.
final class HistoryEvent extends VideEvent {
  final int lastSeq;
  final List<dynamic> events;

  HistoryEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.lastSeq,
    required this.events,
  });

  @override
  String get wireType => 'history';

  @override
  Map<String, dynamic> dataFields() => {'events': events};

  @override
  Map<String, dynamic> topLevelFields() => {'last-seq': lastSeq};
}

/// Assistant or user message content.
///
/// Messages stream as partial chunks with the same [eventId].
/// When [isPartial] is false, the message is complete.
final class MessageEvent extends VideEvent {
  /// Unique ID for this message (shared across partial chunks).
  final String eventId;

  /// Message role: 'user' or 'assistant'.
  final String role;

  /// Message content (may be partial chunk).
  final String content;

  /// True if this is a partial chunk, false if complete.
  final bool isPartial;

  /// Attachments included with this message (only for user messages, first chunk).
  final List<VideAttachment>? attachments;

  MessageEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.eventId,
    required this.role,
    required this.content,
    required this.isPartial,
    this.attachments,
  });

  @override
  String get wireType => 'message';

  @override
  Map<String, dynamic> dataFields() => {
    'role': role,
    'content': content,
    if (attachments != null && attachments!.isNotEmpty)
      'attachments': attachments!
          .map(
            (a) => {
              'type': a.type,
              if (a.filePath != null) 'file-path': a.filePath,
              if (a.content != null) 'content': a.content,
              if (a.mimeType != null) 'mime-type': a.mimeType,
            },
          )
          .toList(),
  };

  @override
  Map<String, dynamic> topLevelFields() => {
    'event-id': eventId,
    'is-partial': isPartial,
  };

  @override
  String toString() =>
      'MessageEvent($role, ${content.length} chars, partial=$isPartial)';
}

/// Agent is invoking a tool.
final class ToolUseEvent extends VideEvent {
  /// Unique ID for this tool use (used to correlate with result).
  final String toolUseId;

  /// Name of the tool being invoked.
  final String toolName;

  /// Input parameters for the tool.
  final Map<String, dynamic> toolInput;

  ToolUseEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.toolUseId,
    required this.toolName,
    required this.toolInput,
  });

  @override
  String get wireType => 'tool-use';

  @override
  Map<String, dynamic> dataFields() => {
    'tool-use-id': toolUseId,
    'tool-name': toolName,
    'tool-input': toolInput,
  };

  @override
  String toString() => 'ToolUseEvent($toolName)';
}

/// Result from a tool execution.
final class ToolResultEvent extends VideEvent {
  /// ID of the tool use this is a result for.
  final String toolUseId;

  /// Name of the tool.
  final String toolName;

  /// Result content (may be error message if [isError] is true).
  final String result;

  /// True if the tool execution failed.
  final bool isError;

  ToolResultEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.toolUseId,
    required this.toolName,
    required this.result,
    required this.isError,
  });

  @override
  String get wireType => 'tool-result';

  @override
  Map<String, dynamic> dataFields() => {
    'tool-use-id': toolUseId,
    'tool-name': toolName,
    'result': result,
    'is-error': isError,
  };

  @override
  String toString() => 'ToolResultEvent($toolName, error=$isError)';
}

/// Agent status changed.
final class StatusEvent extends VideEvent {
  /// New status of the agent.
  final VideAgentStatus status;

  StatusEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.status,
  });

  @override
  String get wireType => 'status';

  @override
  Map<String, dynamic> dataFields() => {'status': status.toWireString()};

  @override
  String toString() => 'StatusEvent($status)';
}

/// Agent completed its turn.
final class TurnCompleteEvent extends VideEvent {
  /// Reason for completion (e.g., "end_turn", "max_tokens").
  final String reason;

  // Token usage (accumulated totals across all turns)
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheReadInputTokens;
  final int totalCacheCreationInputTokens;
  final double totalCostUsd;

  // Current context window usage (from latest turn)
  final int currentContextInputTokens;
  final int currentContextCacheReadTokens;
  final int currentContextCacheCreationTokens;

  TurnCompleteEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.reason,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheReadInputTokens = 0,
    this.totalCacheCreationInputTokens = 0,
    this.totalCostUsd = 0.0,
    this.currentContextInputTokens = 0,
    this.currentContextCacheReadTokens = 0,
    this.currentContextCacheCreationTokens = 0,
  });

  /// Total context tokens used across all turns.
  int get totalContextTokens =>
      totalInputTokens +
      totalCacheReadInputTokens +
      totalCacheCreationInputTokens;

  /// Current context window usage (for percentage display).
  int get currentContextWindowTokens =>
      currentContextInputTokens +
      currentContextCacheReadTokens +
      currentContextCacheCreationTokens;

  @override
  String get wireType => 'done';

  @override
  Map<String, dynamic> dataFields() => {
    'reason': reason,
    'total-input-tokens': totalInputTokens,
    'total-output-tokens': totalOutputTokens,
    'total-cache-read-input-tokens': totalCacheReadInputTokens,
    'total-cache-creation-input-tokens': totalCacheCreationInputTokens,
    'total-cost-usd': totalCostUsd,
    'current-context-input-tokens': currentContextInputTokens,
    'current-context-cache-read-tokens': currentContextCacheReadTokens,
    'current-context-cache-creation-tokens': currentContextCacheCreationTokens,
  };

  @override
  String toString() => 'TurnCompleteEvent($reason)';
}

/// A new agent was spawned into the network.
final class AgentSpawnedEvent extends VideEvent {
  /// ID of the agent that spawned this one.
  final String spawnedBy;

  AgentSpawnedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.spawnedBy,
  });

  @override
  String get wireType => 'agent-spawned';

  @override
  Map<String, dynamic> dataFields() => {'spawned-by': spawnedBy};

  @override
  String toString() => 'AgentSpawnedEvent($agentName, by $spawnedBy)';
}

/// An agent was terminated and removed from the network.
final class AgentTerminatedEvent extends VideEvent {
  /// Reason for termination.
  final String? reason;

  /// ID of the agent that requested termination.
  final String? terminatedBy;

  AgentTerminatedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    this.reason,
    this.terminatedBy,
  });

  @override
  String get wireType => 'agent-terminated';

  @override
  Map<String, dynamic> dataFields() => {
    'reason': reason,
    'terminated-by': terminatedBy,
  };

  @override
  String toString() => 'AgentTerminatedEvent($agentId, reason=$reason)';
}

/// Permission is required to use a tool.
///
/// Call [VideSession.respondToPermission] to allow or deny.
final class PermissionRequestEvent extends VideEvent {
  /// Unique ID for this permission request.
  final String requestId;

  /// Name of the tool requesting permission.
  final String toolName;

  /// Input parameters for the tool.
  final Map<String, dynamic> toolInput;

  /// Inferred permission pattern (e.g., "Bash(git status:*)").
  final String? inferredPattern;

  PermissionRequestEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    this.inferredPattern,
  });

  @override
  String get wireType => 'permission-request';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'tool': {
      'name': toolName,
      'input': toolInput,
      if (inferredPattern != null) 'permission-suggestions': [inferredPattern],
    },
  };

  @override
  String toString() => 'PermissionRequestEvent($toolName, $requestId)';
}

/// Permission request was resolved (allowed or denied) by a client.
///
/// Broadcast to all connected clients so they can dismiss stale permission UI.
final class PermissionResolvedEvent extends VideEvent {
  final String requestId;
  final bool allow;
  final String? message;

  PermissionResolvedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.allow,
    this.message,
  });

  @override
  String get wireType => 'permission-resolved';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'allow': allow,
    if (message != null) 'message': message,
  };

  @override
  String toString() => 'PermissionResolvedEvent($requestId, allow=$allow)';
}

/// Agent needs to ask the user a question (AskUserQuestion tool).
final class AskUserQuestionEvent extends VideEvent {
  /// Unique ID for this request.
  final String requestId;

  /// The questions to ask the user.
  final List<AskUserQuestionData> questions;

  AskUserQuestionEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.questions,
  });

  @override
  String get wireType => 'ask-user-question';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'questions': questions
        .map(
          (q) => {
            'question': q.question,
            'header': q.header,
            'multi-select': q.multiSelect,
            'options': q.options
                .map((o) => {'label': o.label, 'description': o.description})
                .toList(),
          },
        )
        .toList(),
  };

  @override
  String toString() =>
      'AskUserQuestionEvent($requestId, ${questions.length} questions)';
}

/// AskUserQuestion was resolved (answered) by a client.
///
/// Broadcast to all connected clients so they can dismiss stale question UI.
final class AskUserQuestionResolvedEvent extends VideEvent {
  final String requestId;
  final Map<String, String> answers;

  AskUserQuestionResolvedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.answers,
  });

  @override
  String get wireType => 'ask-user-question-resolved';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'answers': answers,
  };

  @override
  String toString() => 'AskUserQuestionResolvedEvent($requestId)';
}

/// Data for a single question in AskUserQuestionEvent.
class AskUserQuestionData {
  final String question;
  final String? header;
  final bool multiSelect;
  final List<AskUserQuestionOptionData> options;

  const AskUserQuestionData({
    required this.question,
    this.header,
    this.multiSelect = false,
    required this.options,
  });
}

/// Data for a single option in AskUserQuestionData.
class AskUserQuestionOptionData {
  final String label;
  final String description;

  const AskUserQuestionOptionData({
    required this.label,
    required this.description,
  });
}

/// Plan approval is required before implementation begins.
///
/// Emitted when an agent calls `ExitPlanMode`. The plan content is extracted
/// from the agent's conversation (the assistant text preceding the tool call).
/// Call [VideSession.respondToPlanApproval] to accept or reject.
final class PlanApprovalRequestEvent extends VideEvent {
  /// Unique ID for this approval request.
  final String requestId;

  /// The markdown plan content to display to the user.
  final String planContent;

  /// Pre-requested Bash permissions for the implementation phase.
  final List<Map<String, dynamic>>? allowedPrompts;

  PlanApprovalRequestEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.planContent,
    this.allowedPrompts,
  });

  @override
  String get wireType => 'plan-approval-request';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'plan-content': planContent,
    if (allowedPrompts != null) 'allowed-prompts': allowedPrompts,
  };

  @override
  String toString() => 'PlanApprovalRequestEvent($requestId)';
}

/// Plan approval was resolved (accepted or rejected) by a client.
///
/// Broadcast to all connected clients so they can dismiss stale plan approval UI.
final class PlanApprovalResolvedEvent extends VideEvent {
  final String requestId;

  /// The user's action: 'accept' or 'reject'.
  final String action;

  /// Optional feedback when rejecting (sent back to Claude as deny message).
  final String? feedback;

  PlanApprovalResolvedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.action,
    this.feedback,
  });

  @override
  String get wireType => 'plan-approval-resolved';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'action': action,
    if (feedback != null) 'feedback': feedback,
  };

  @override
  String toString() => 'PlanApprovalResolvedEvent($requestId, action=$action)';
}

/// The session/network goal (task name) was changed.
final class TaskNameChangedEvent extends VideEvent {
  /// The new goal/task name.
  final String newGoal;

  /// The previous goal/task name.
  final String? previousGoal;

  TaskNameChangedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.newGoal,
    this.previousGoal,
  });

  @override
  String get wireType => 'task-name-changed';

  @override
  Map<String, dynamic> dataFields() => {
    'new-goal': newGoal,
    if (previousGoal != null) 'previous-goal': previousGoal,
  };

  @override
  String toString() => 'TaskNameChangedEvent($previousGoal -> $newGoal)';
}

/// Processing aborted.
final class AbortedEvent extends VideEvent {
  AbortedEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
  });

  @override
  String get wireType => 'aborted';

  @override
  Map<String, dynamic> dataFields() => {};
}

/// An error occurred.
final class ErrorEvent extends VideEvent {
  /// Error message.
  final String message;

  /// Error code (if available).
  final String? code;

  ErrorEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.message,
    this.code,
  });

  @override
  String get wireType => 'error';

  @override
  Map<String, dynamic> dataFields() => {
    'message': message,
    if (code != null) 'code': code,
  };

  @override
  String toString() => 'ErrorEvent($message, code=$code)';
}

/// Result of a session command request (client-specific, not part of history).
final class CommandResultEvent extends VideEvent {
  final String requestId;
  final String command;
  final bool success;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  final String? errorCode;

  CommandResultEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.command,
    required this.success,
    this.result,
    this.errorMessage,
    this.errorCode,
  });

  @override
  String get wireType => 'command-result';

  @override
  Map<String, dynamic> dataFields() => {
    'request-id': requestId,
    'command': command,
    'success': success,
    if (result != null) 'result': result,
    if (errorMessage != null || errorCode != null)
      'error': {
        if (errorMessage != null) 'message': errorMessage,
        if (errorCode != null) 'code': errorCode,
      },
  };
}

/// Unknown event type.
final class UnknownEvent extends VideEvent {
  final String type;
  final Map<String, dynamic> rawData;

  UnknownEvent({
    super.seq,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.type,
    required this.rawData,
  });

  @override
  String get wireType => type;

  @override
  Map<String, dynamic> dataFields() => rawData;
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

String? _extractInferredPattern(dynamic tool) {
  if (tool is! Map<String, dynamic>) return null;
  final suggestions = tool['permission-suggestions'] as List<dynamic>?;
  if (suggestions == null || suggestions.isEmpty) return null;
  return suggestions.first as String?;
}

List<VideAttachment>? _parseAttachments(dynamic attachmentsJson) {
  if (attachmentsJson is! List || attachmentsJson.isEmpty) return null;
  return attachmentsJson.map((a) {
    final map = a is Map<String, dynamic> ? a : <String, dynamic>{};
    return VideAttachment(
      type: map['type'] as String? ?? 'file',
      filePath: map['file-path'] as String?,
      content: map['content'] as String?,
      mimeType: map['mime-type'] as String?,
    );
  }).toList();
}

List<AskUserQuestionData> _parseQuestions(dynamic questionsJson) {
  if (questionsJson is! List) return [];
  return questionsJson.map((q) {
    final qMap = q is Map<String, dynamic> ? q : <String, dynamic>{};
    final optionsList = qMap['options'] as List<dynamic>? ?? [];
    return AskUserQuestionData(
      question: qMap['question'] as String? ?? '',
      header: qMap['header'] as String?,
      multiSelect: qMap['multi-select'] as bool? ?? false,
      options: optionsList.map((o) {
        final oMap = o is Map<String, dynamic> ? o : <String, dynamic>{};
        return AskUserQuestionOptionData(
          label: oMap['label']?.toString() ?? '',
          description: oMap['description']?.toString() ?? '',
        );
      }).toList(),
    );
  }).toList();
}
