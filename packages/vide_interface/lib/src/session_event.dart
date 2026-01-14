/// Server-to-client events for vide sessions.

import 'models.dart';

/// Base class for all session events sent from server to client.
sealed class SessionEvent {
  /// The ID of the agent that generated this event (null for session-level events).
  final String? agentId;

  /// When the event occurred.
  final DateTime timestamp;

  const SessionEvent({
    required this.agentId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson();

  static SessionEvent fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'connected' => ConnectedEvent.fromJson(json),
      'message' => MessageEvent.fromJson(json),
      'tool-use' => ToolUseEvent.fromJson(json),
      'tool-result' => ToolResultEvent.fromJson(json),
      'permission-request' => PermissionRequestEvent.fromJson(json),
      'agent-spawned' => AgentSpawnedEvent.fromJson(json),
      'agent-terminated' => AgentTerminatedEvent.fromJson(json),
      'agent-status' => AgentStatusEvent.fromJson(json),
      'error' => ErrorEvent.fromJson(json),
      'client-joined' => ClientJoinedEvent.fromJson(json),
      'client-left' => ClientLeftEvent.fromJson(json),
      'turn-complete' => TurnCompleteEvent.fromJson(json),
      'permission-timeout' => PermissionTimeoutEvent.fromJson(json),
      'aborted' => AbortedEvent.fromJson(json),
      _ => throw ArgumentError('Unknown event type: $type'),
    };
  }
}

/// Wrapper for sequenced events (used for ordering and reconnection deduplication).
/// This is a transport concern, not part of the core event types.
final class SequencedEvent {
  final int seq;
  final SessionEvent event;

  const SequencedEvent({
    required this.seq,
    required this.event,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        ...event.toJson(),
      };

  factory SequencedEvent.fromJson(Map<String, dynamic> json) {
    return SequencedEvent(
      seq: json['seq'] as int,
      event: SessionEvent.fromJson(json),
    );
  }
}

/// Connection established with session info.
final class ConnectedEvent extends SessionEvent {
  final SessionInfo sessionInfo;
  final List<ConnectedClient> clients;

  const ConnectedEvent({
    required super.timestamp,
    required this.sessionInfo,
    required this.clients,
  }) : super(agentId: null);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'connected',
        'timestamp': timestamp.toIso8601String(),
        'session-info': sessionInfo.toJson(),
        'clients': clients.map((c) => c.toJson()).toList(),
      };

  factory ConnectedEvent.fromJson(Map<String, dynamic> json) {
    return ConnectedEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionInfo:
          SessionInfo.fromJson(json['session-info'] as Map<String, dynamic>),
      clients: (json['clients'] as List<dynamic>)
          .map((c) => ConnectedClient.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A message from an agent (streaming or complete).
final class MessageEvent extends SessionEvent {
  final String role;
  final String content;
  final bool isPartial;
  final String eventId;

  const MessageEvent({
    required super.agentId,
    required super.timestamp,
    required this.role,
    required this.content,
    required this.isPartial,
    required this.eventId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'message',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'role': role,
        'content': content,
        'is-partial': isPartial,
        'event-id': eventId,
      };

  factory MessageEvent.fromJson(Map<String, dynamic> json) {
    return MessageEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      role: json['role'] as String,
      content: json['content'] as String,
      isPartial: json['is-partial'] as bool,
      eventId: json['event-id'] as String,
    );
  }
}

/// An agent is invoking a tool.
final class ToolUseEvent extends SessionEvent {
  final String toolName;
  final String toolId;
  final Map<String, dynamic> input;

  const ToolUseEvent({
    required super.agentId,
    required super.timestamp,
    required this.toolName,
    required this.toolId,
    required this.input,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool-use',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'tool-name': toolName,
        'tool-id': toolId,
        'input': input,
      };

  factory ToolUseEvent.fromJson(Map<String, dynamic> json) {
    return ToolUseEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolName: json['tool-name'] as String,
      toolId: json['tool-id'] as String,
      input: json['input'] as Map<String, dynamic>,
    );
  }
}

/// Result from a tool execution.
final class ToolResultEvent extends SessionEvent {
  final String toolId;
  final String output;
  final bool isError;

  const ToolResultEvent({
    required super.agentId,
    required super.timestamp,
    required this.toolId,
    required this.output,
    required this.isError,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool-result',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'tool-id': toolId,
        'output': output,
        'is-error': isError,
      };

  factory ToolResultEvent.fromJson(Map<String, dynamic> json) {
    return ToolResultEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolId: json['tool-id'] as String,
      output: json['output'] as String,
      isError: json['is-error'] as bool,
    );
  }
}

/// A tool requires user permission before execution.
final class PermissionRequestEvent extends SessionEvent {
  final String requestId;
  final String toolName;
  final String description;
  final Map<String, dynamic> input;

  const PermissionRequestEvent({
    required super.agentId,
    required super.timestamp,
    required this.requestId,
    required this.toolName,
    required this.description,
    required this.input,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'permission-request',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'request-id': requestId,
        'tool-name': toolName,
        'description': description,
        'input': input,
      };

  factory PermissionRequestEvent.fromJson(Map<String, dynamic> json) {
    return PermissionRequestEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestId: json['request-id'] as String,
      toolName: json['tool-name'] as String,
      description: json['description'] as String,
      input: json['input'] as Map<String, dynamic>,
    );
  }
}

/// A new agent was spawned in the session.
final class AgentSpawnedEvent extends SessionEvent {
  final String spawnedAgentId;
  final String name;
  final String type;

  const AgentSpawnedEvent({
    required super.agentId,
    required super.timestamp,
    required this.spawnedAgentId,
    required this.name,
    required this.type,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'agent-spawned',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'spawned-agent-id': spawnedAgentId,
        'name': name,
        'agent-type': type,
      };

  factory AgentSpawnedEvent.fromJson(Map<String, dynamic> json) {
    return AgentSpawnedEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      spawnedAgentId: json['spawned-agent-id'] as String,
      name: json['name'] as String,
      type: json['agent-type'] as String,
    );
  }
}

/// An agent was terminated.
final class AgentTerminatedEvent extends SessionEvent {
  final String terminatedAgentId;
  final String? reason;

  const AgentTerminatedEvent({
    required super.agentId,
    required super.timestamp,
    required this.terminatedAgentId,
    required this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'agent-terminated',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'terminated-agent-id': terminatedAgentId,
        'reason': reason,
      };

  factory AgentTerminatedEvent.fromJson(Map<String, dynamic> json) {
    return AgentTerminatedEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      terminatedAgentId: json['terminated-agent-id'] as String,
      reason: json['reason'] as String?,
    );
  }
}

/// An agent's status changed.
final class AgentStatusEvent extends SessionEvent {
  final String statusAgentId;
  final AgentStatus status;

  const AgentStatusEvent({
    required super.agentId,
    required super.timestamp,
    required this.statusAgentId,
    required this.status,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'agent-status',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'status-agent-id': statusAgentId,
        'status': status.name,
      };

  factory AgentStatusEvent.fromJson(Map<String, dynamic> json) {
    return AgentStatusEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      statusAgentId: json['status-agent-id'] as String,
      status: AgentStatus.values.byName(json['status'] as String),
    );
  }
}

/// An error occurred in the session.
final class ErrorEvent extends SessionEvent {
  final String code;
  final String message;

  const ErrorEvent({
    required super.agentId,
    required super.timestamp,
    required this.code,
    required this.message,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'error',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'code': code,
        'message': message,
      };

  factory ErrorEvent.fromJson(Map<String, dynamic> json) {
    return ErrorEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }
}

/// A new client connected to the session.
final class ClientJoinedEvent extends SessionEvent {
  final String clientId;
  final String? remoteAddress;

  const ClientJoinedEvent({
    required super.timestamp,
    required this.clientId,
    required this.remoteAddress,
  }) : super(agentId: null);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'client-joined',
        'timestamp': timestamp.toIso8601String(),
        'client-id': clientId,
        'remote-address': remoteAddress,
      };

  factory ClientJoinedEvent.fromJson(Map<String, dynamic> json) {
    return ClientJoinedEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      clientId: json['client-id'] as String,
      remoteAddress: json['remote-address'] as String?,
    );
  }
}

/// A client disconnected from the session.
final class ClientLeftEvent extends SessionEvent {
  final String clientId;

  const ClientLeftEvent({
    required super.timestamp,
    required this.clientId,
  }) : super(agentId: null);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'client-left',
        'timestamp': timestamp.toIso8601String(),
        'client-id': clientId,
      };

  factory ClientLeftEvent.fromJson(Map<String, dynamic> json) {
    return ClientLeftEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      clientId: json['client-id'] as String,
    );
  }
}

/// An agent completed its turn.
final class TurnCompleteEvent extends SessionEvent {
  final String? reason;

  const TurnCompleteEvent({
    required super.agentId,
    required super.timestamp,
    this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'turn-complete',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        if (reason != null) 'reason': reason,
      };

  factory TurnCompleteEvent.fromJson(Map<String, dynamic> json) {
    return TurnCompleteEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reason: json['reason'] as String?,
    );
  }
}

/// A permission request timed out without a response.
final class PermissionTimeoutEvent extends SessionEvent {
  final String requestId;

  const PermissionTimeoutEvent({
    required super.agentId,
    required super.timestamp,
    required this.requestId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'permission-timeout',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
        'request-id': requestId,
      };

  factory PermissionTimeoutEvent.fromJson(Map<String, dynamic> json) {
    return PermissionTimeoutEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestId: json['request-id'] as String,
    );
  }
}

/// An operation was aborted by the user.
final class AbortedEvent extends SessionEvent {
  const AbortedEvent({
    required super.agentId,
    required super.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'aborted',
        'agent-id': agentId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AbortedEvent.fromJson(Map<String, dynamic> json) {
    return AbortedEvent(
      agentId: json['agent-id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
