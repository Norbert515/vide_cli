import 'agent_info.dart';
import 'enums.dart';

/// Base class for all vide_server WebSocket events.
sealed class VideEvent {
  final int? seq;
  final String? eventId;
  final DateTime timestamp;
  final AgentInfo? agent;

  const VideEvent({
    this.seq,
    this.eventId,
    required this.timestamp,
    this.agent,
  });

  /// Parse a JSON event from the server.
  ///
  /// IMPORTANT: Required fields use non-nullable casts (e.g., `as String`)
  /// intentionally. If a required field is missing, this will throw at runtime.
  /// This is by design - we want to catch server/client mismatches immediately
  /// rather than silently substituting empty strings that hide errors.
  factory VideEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final seq = json['seq'] as int?;
    final eventId = json['event-id'] as String?;
    final agent = json['agent-id'] != null ? AgentInfo.fromJson(json) : null;
    final data = json['data'] as Map<String, dynamic>?;

    return switch (type) {
      'connected' => ConnectedEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required fields - will throw if missing (intentional)
          sessionId: json['session-id'] as String,
          mainAgentId: json['main-agent-id'] as String,
          lastSeq: json['last-seq'] as int? ?? 0,
          agents: (json['agents'] as List<dynamic>?)
                  ?.map((a) => AgentInfo.fromJson(a as Map<String, dynamic>))
                  .toList() ??
              [],
        ),
      'history' => HistoryEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          lastSeq: json['last-seq'] as int? ?? 0,
          events: data?['events'] as List<dynamic>? ?? [],
        ),
      'message' => MessageEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          role: MessageRole.fromString(data?['role'] as String? ?? 'assistant'),
          content: data?['content'] as String? ?? '',
          isPartial: json['is-partial'] as bool? ?? false,
        ),
      'status' => StatusEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          status: AgentStatus.fromString(data?['status'] as String?),
        ),
      'tool-use' => ToolUseEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required fields - will throw if missing (intentional)
          toolUseId: data!['tool-use-id'] as String,
          toolName: data['tool-name'] as String,
          toolInput: data['tool-input'] as Map<String, dynamic>? ?? {},
        ),
      'tool-result' => ToolResultEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required fields - will throw if missing (intentional)
          toolUseId: data!['tool-use-id'] as String,
          toolName: data['tool-name'] as String,
          result: data['result'],
          isError: data['is-error'] as bool? ?? false,
        ),
      'permission-request' => PermissionRequestEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required fields - will throw if missing (intentional)
          requestId: data!['request-id'] as String,
          tool: data['tool'] as Map<String, dynamic>,
        ),
      'permission-timeout' => PermissionTimeoutEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required field - will throw if missing (intentional)
          requestId: data!['request-id'] as String,
        ),
      'agent-spawned' => AgentSpawnedEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required field - will throw if missing (intentional)
          spawnedBy: data!['spawned-by'] as String,
        ),
      'agent-terminated' => AgentTerminatedEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required field - will throw if missing (intentional)
          terminatedBy: data!['terminated-by'] as String,
          reason: data['reason'] as String?,
        ),
      'done' => DoneEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          reason: data?['reason'] as String? ?? 'complete',
        ),
      'aborted' => AbortedEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
        ),
      'error' => ErrorEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          // Required field - will throw if missing (intentional)
          message: data!['message'] as String,
          code: data['code'] as String?,
        ),
      _ => UnknownEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          type: type,
          rawData: json,
        ),
    };
  }
}

/// WebSocket connection established.
class ConnectedEvent extends VideEvent {
  final String sessionId;
  final String mainAgentId;
  final int lastSeq;
  final List<AgentInfo> agents;

  const ConnectedEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.sessionId,
    required this.mainAgentId,
    required this.lastSeq,
    required this.agents,
  });
}

/// Session history for reconnection.
class HistoryEvent extends VideEvent {
  final int lastSeq;
  final List<dynamic> events;

  const HistoryEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.lastSeq,
    required this.events,
  });
}

/// Streaming message chunk or complete message.
class MessageEvent extends VideEvent {
  final MessageRole role;
  final String content;
  final bool isPartial;

  const MessageEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.role,
    required this.content,
    required this.isPartial,
  });
}

/// Agent status change.
class StatusEvent extends VideEvent {
  final AgentStatus status;

  const StatusEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.status,
  });
}

/// Agent invoking a tool.
class ToolUseEvent extends VideEvent {
  final String toolUseId;
  final String toolName;
  final Map<String, dynamic> toolInput;

  const ToolUseEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.toolUseId,
    required this.toolName,
    required this.toolInput,
  });
}

/// Tool execution result.
class ToolResultEvent extends VideEvent {
  final String toolUseId;
  final String toolName;
  final dynamic result;
  final bool isError;

  const ToolResultEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.toolUseId,
    required this.toolName,
    this.result,
    required this.isError,
  });
}

/// Permission request from agent.
class PermissionRequestEvent extends VideEvent {
  final String requestId;
  final Map<String, dynamic> tool;

  const PermissionRequestEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.requestId,
    required this.tool,
  });

  String get toolName => tool['name'] as String? ?? '';
}

/// Permission request timed out.
class PermissionTimeoutEvent extends VideEvent {
  final String requestId;

  const PermissionTimeoutEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.requestId,
  });
}

/// New agent spawned.
class AgentSpawnedEvent extends VideEvent {
  final String spawnedBy;

  const AgentSpawnedEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.spawnedBy,
  });
}

/// Agent terminated.
class AgentTerminatedEvent extends VideEvent {
  final String terminatedBy;
  final String? reason;

  const AgentTerminatedEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.terminatedBy,
    this.reason,
  });
}

/// Turn complete.
class DoneEvent extends VideEvent {
  final String reason;

  const DoneEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.reason,
  });
}

/// Processing aborted.
class AbortedEvent extends VideEvent {
  const AbortedEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
  });
}

/// Error occurred.
class ErrorEvent extends VideEvent {
  final String message;
  final String? code;

  const ErrorEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.message,
    this.code,
  });
}

/// Unknown event type.
class UnknownEvent extends VideEvent {
  final String type;
  final Map<String, dynamic> rawData;

  const UnknownEvent({
    super.seq,
    super.eventId,
    required super.timestamp,
    super.agent,
    required this.type,
    required this.rawData,
  });
}
