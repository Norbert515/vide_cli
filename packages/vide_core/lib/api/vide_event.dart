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

  TurnCompleteEvent({
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    super.timestamp,
    required this.reason,
  });

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
