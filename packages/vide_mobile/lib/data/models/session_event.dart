import '../../domain/models/agent.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/permission_request.dart';
import '../../domain/models/tool_event.dart';

/// Base class for all session events from WebSocket.
sealed class SessionEvent {
  final int seq;
  final String eventId;
  final String agentId;
  final String agentType;
  final String? agentName;
  final String? taskName;
  final DateTime timestamp;

  SessionEvent({
    required this.seq,
    required this.eventId,
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    required this.timestamp,
  });

  /// Parses a WebSocket message into a SessionEvent.
  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final seq = json['seq'] as int;
    final eventId = json['event-id'] as String? ?? '';
    final agentId = json['agent-id'] as String? ?? '';
    final agentType = json['agent-type'] as String? ?? '';
    final agentName = json['agent-name'] as String?;
    final taskName = json['task-name'] as String?;
    final timestamp = json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now();

    final data = json['data'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'connected':
        return ConnectedEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          sessionId: data['session-id'] as String? ?? '',
          lastSeq: data['last-seq'] as int? ?? 0,
          agents: (data['agents'] as List<dynamic>?)
                  ?.map((a) => Agent.fromJson(a as Map<String, dynamic>))
                  .toList() ??
              [],
        );

      case 'history':
        final events = (data['events'] as List<dynamic>?)
                ?.map((e) => SessionEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return HistoryEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          events: events,
        );

      case 'status':
        return StatusEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          status: _parseAgentStatus(data['status'] as String? ?? 'idle'),
        );

      case 'message':
        final role = data['role'] as String? ?? 'assistant';
        return MessageEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          role: role == 'user' ? MessageRole.user : MessageRole.assistant,
          content: data['content'] as String? ?? '',
          isPartial: json['is-partial'] as bool? ?? false,
        );

      case 'tool-use':
        return ToolUseEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          toolUse: ToolUse(
            toolUseId: data['tool-use-id'] as String? ?? eventId,
            toolName: data['tool-name'] as String? ?? '',
            input: data['input'] as Map<String, dynamic>? ?? {},
            agentId: agentId,
            agentName: agentName,
            timestamp: timestamp,
          ),
        );

      case 'tool-result':
        return ToolResultEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          toolResult: ToolResult(
            toolUseId: data['tool-use-id'] as String? ?? '',
            toolName: data['tool-name'] as String? ?? '',
            result: data['result'],
            isError: data['is-error'] as bool? ?? false,
            timestamp: timestamp,
          ),
        );

      case 'permission-request':
        return PermissionRequestEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          request: PermissionRequest(
            requestId: data['request-id'] as String? ?? eventId,
            toolName: data['tool-name'] as String? ?? '',
            toolInput: data['tool-input'] as Map<String, dynamic>? ?? {},
            agentId: agentId,
            agentName: agentName,
            permissionSuggestions:
                (data['permission-suggestions'] as List<dynamic>?)
                    ?.cast<String>(),
            timestamp: timestamp,
          ),
        );

      case 'permission-timeout':
        return PermissionTimeoutEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          requestId: data['request-id'] as String? ?? '',
        );

      case 'agent-spawned':
        return AgentSpawnedEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          agent: Agent.fromJson(data),
        );

      case 'agent-terminated':
        return AgentTerminatedEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          terminatedAgentId: data['agent-id'] as String? ?? agentId,
          reason: data['reason'] as String?,
        );

      case 'done':
        return DoneEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          reason: data['reason'] as String?,
        );

      case 'aborted':
        return AbortedEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
        );

      case 'error':
        return ErrorEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          code: data['code'] as String? ?? 'unknown',
          message: data['message'] as String? ?? 'Unknown error',
        );

      default:
        return UnknownEvent(
          seq: seq,
          eventId: eventId,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: timestamp,
          type: type,
          data: data,
        );
    }
  }

  static AgentStatus _parseAgentStatus(String status) {
    switch (status) {
      case 'working':
        return AgentStatus.working;
      case 'waiting-for-agent':
        return AgentStatus.waitingForAgent;
      case 'waiting-for-user':
        return AgentStatus.waitingForUser;
      case 'idle':
      default:
        return AgentStatus.idle;
    }
  }
}

/// Event received when WebSocket connection is established.
class ConnectedEvent extends SessionEvent {
  final String sessionId;
  final int lastSeq;
  final List<Agent> agents;

  ConnectedEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.sessionId,
    required this.lastSeq,
    required this.agents,
  });
}

/// Event containing session history for reconnection.
class HistoryEvent extends SessionEvent {
  final List<SessionEvent> events;

  HistoryEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.events,
  });
}

/// Event when agent status changes.
class StatusEvent extends SessionEvent {
  final AgentStatus status;

  StatusEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.status,
  });
}

/// Event for streaming message content.
class MessageEvent extends SessionEvent {
  final MessageRole role;
  final String content;
  final bool isPartial;

  MessageEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.role,
    required this.content,
    required this.isPartial,
  });
}

/// Event when agent invokes a tool.
class ToolUseEvent extends SessionEvent {
  final ToolUse toolUse;

  ToolUseEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.toolUse,
  });
}

/// Event when tool returns a result.
class ToolResultEvent extends SessionEvent {
  final ToolResult toolResult;

  ToolResultEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.toolResult,
  });
}

/// Event when agent requests permission.
class PermissionRequestEvent extends SessionEvent {
  final PermissionRequest request;

  PermissionRequestEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.request,
  });
}

/// Event when permission request times out.
class PermissionTimeoutEvent extends SessionEvent {
  final String requestId;

  PermissionTimeoutEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.requestId,
  });
}

/// Event when a new agent is spawned.
class AgentSpawnedEvent extends SessionEvent {
  final Agent agent;

  AgentSpawnedEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.agent,
  });
}

/// Event when an agent is terminated.
class AgentTerminatedEvent extends SessionEvent {
  final String terminatedAgentId;
  final String? reason;

  AgentTerminatedEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.terminatedAgentId,
    this.reason,
  });
}

/// Event when agent turn is complete.
class DoneEvent extends SessionEvent {
  final String? reason;

  DoneEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    this.reason,
  });
}

/// Event when operation is aborted.
class AbortedEvent extends SessionEvent {
  AbortedEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
  });
}

/// Event for errors.
class ErrorEvent extends SessionEvent {
  final String code;
  final String message;

  ErrorEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.code,
    required this.message,
  });
}

/// Event for unknown/unrecognized event types.
class UnknownEvent extends SessionEvent {
  final String type;
  final Map<String, dynamic> data;

  UnknownEvent({
    required super.seq,
    required super.eventId,
    required super.agentId,
    required super.agentType,
    super.agentName,
    super.taskName,
    required super.timestamp,
    required this.type,
    required this.data,
  });
}
