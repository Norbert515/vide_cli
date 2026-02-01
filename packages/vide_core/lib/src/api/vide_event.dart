/// Sealed event hierarchy for the VideCore API.
///
/// All events from all agents are multiplexed into a single stream.
/// Events do NOT include sequence numbers - transport layers add those.
library;

import 'vide_agent.dart';

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
///     // ... handle other events
///   }
/// });
/// ```
sealed class VideEvent {
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
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
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

  MessageEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.eventId,
    required this.role,
    required this.content,
    required this.isPartial,
  });

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
  String toString() => 'ToolResultEvent($toolName, error=$isError)';
}

/// Agent status changed.
final class StatusEvent extends VideEvent {
  /// New status of the agent.
  final VideAgentStatus status;

  StatusEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.status,
  });

  @override
  String toString() => 'StatusEvent($status)';
}

/// Agent completed its turn.
final class TurnCompleteEvent extends VideEvent {
  /// Reason for completion (e.g., "end_turn", "max_tokens").
  final String reason;

  // Token usage (accumulated totals across all turns)
  /// Total input tokens used across all turns.
  final int totalInputTokens;

  /// Total output tokens used across all turns.
  final int totalOutputTokens;

  /// Total cache read tokens used across all turns.
  final int totalCacheReadInputTokens;

  /// Total cache creation tokens used across all turns.
  final int totalCacheCreationInputTokens;

  /// Total cost in USD across all turns.
  final double totalCostUsd;

  // Current context window usage (from latest turn, for context % display)
  /// Input tokens in current context window.
  final int currentContextInputTokens;

  /// Cache read tokens in current context window.
  final int currentContextCacheReadTokens;

  /// Cache creation tokens in current context window.
  final int currentContextCacheCreationTokens;

  TurnCompleteEvent({
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
  String toString() => 'TurnCompleteEvent($reason)';
}

/// A new agent was spawned into the network.
final class AgentSpawnedEvent extends VideEvent {
  /// ID of the agent that spawned this one.
  final String spawnedBy;

  AgentSpawnedEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.spawnedBy,
  });

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
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    this.reason,
    this.terminatedBy,
  });

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
  String toString() => 'PermissionRequestEvent($toolName, $requestId)';
}

/// An error occurred.
final class ErrorEvent extends VideEvent {
  /// Error message.
  final String message;

  /// Error code (if available).
  final String? code;

  ErrorEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.message,
    this.code,
  });

  @override
  String toString() => 'ErrorEvent($message, code=$code)';
}

/// Agent needs to ask the user a question (AskUserQuestion tool).
///
/// Call [VideSession.respondToAskUserQuestion] to provide answers.
final class AskUserQuestionEvent extends VideEvent {
  /// Unique ID for this request.
  final String requestId;

  /// The questions to ask the user.
  final List<AskUserQuestionData> questions;

  AskUserQuestionEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.requestId,
    required this.questions,
  });

  @override
  String toString() =>
      'AskUserQuestionEvent($requestId, ${questions.length} questions)';
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

/// The session/network goal (task name) was changed.
///
/// This is emitted when the main task name is updated via setTaskName MCP tool.
final class TaskNameChangedEvent extends VideEvent {
  /// The new goal/task name.
  final String newGoal;

  /// The previous goal/task name.
  final String? previousGoal;

  TaskNameChangedEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.newGoal,
    this.previousGoal,
  });

  @override
  String toString() => 'TaskNameChangedEvent($previousGoal -> $newGoal)';
}
