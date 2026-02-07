import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Request to create a new session (Phase 2.5 terminology)
class CreateSessionRequest {
  final String initialMessage;
  final String workingDirectory;
  final String? model;
  final String? permissionMode;
  final String? team;

  CreateSessionRequest({
    required this.initialMessage,
    required this.workingDirectory,
    this.model,
    this.permissionMode,
    this.team,
  });

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) {
    return CreateSessionRequest(
      initialMessage: json['initial-message'] as String,
      workingDirectory: json['working-directory'] as String,
      model: json['model'] as String?,
      permissionMode: json['permission-mode'] as String?,
      team: json['team'] as String?,
    );
  }
}

/// Response from creating a new session
class CreateSessionResponse {
  final String sessionId;
  final String mainAgentId;
  final DateTime createdAt;

  CreateSessionResponse({
    required this.sessionId,
    required this.mainAgentId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'session-id': sessionId,
    'main-agent-id': mainAgentId,
    'created-at': createdAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Client message types (client → server)
abstract class ClientMessage {
  String get type;

  factory ClientMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'user-message':
        return UserMessage.fromJson(json);
      case 'permission-response':
        return PermissionResponse.fromJson(json);
      case 'ask-user-question-response':
        return AskUserQuestionResponseMessage.fromJson(json);
      case 'session-command':
        return SessionCommandMessage.fromJson(json);
      case 'abort':
        return AbortMessage();
      default:
        throw ArgumentError('Unknown message type: $type');
    }
  }
}

/// User message (client → server)
class UserMessage implements ClientMessage {
  @override
  String get type => 'user-message';

  final String content;
  final String? agentId;
  final String? model;
  final String? permissionMode;

  UserMessage({
    required this.content,
    this.agentId,
    this.model,
    this.permissionMode,
  });

  factory UserMessage.fromJson(Map<String, dynamic> json) {
    return UserMessage(
      content: json['content'] as String,
      agentId: json['agent-id'] as String?,
      model: json['model'] as String?,
      permissionMode: json['permission-mode'] as String?,
    );
  }
}

/// Permission response (client → server)
class PermissionResponse implements ClientMessage {
  @override
  String get type => 'permission-response';

  final String requestId;
  final bool allow;
  final String? message;

  PermissionResponse({
    required this.requestId,
    required this.allow,
    this.message,
  });

  factory PermissionResponse.fromJson(Map<String, dynamic> json) {
    return PermissionResponse(
      requestId: json['request-id'] as String,
      allow: json['allow'] as bool,
      message: json['message'] as String?,
    );
  }
}

/// AskUserQuestion response (client -> server)
class AskUserQuestionResponseMessage implements ClientMessage {
  @override
  String get type => 'ask-user-question-response';

  final String requestId;
  final Map<String, String> answers;

  AskUserQuestionResponseMessage({
    required this.requestId,
    required this.answers,
  });

  factory AskUserQuestionResponseMessage.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    return AskUserQuestionResponseMessage(
      requestId: json['request-id'] as String,
      answers: rawAnswers.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }
}

/// Generic session command request (client -> server)
class SessionCommandMessage implements ClientMessage {
  @override
  String get type => 'session-command';

  final String requestId;
  final String command;
  final Map<String, dynamic> data;

  SessionCommandMessage({
    required this.requestId,
    required this.command,
    required this.data,
  });

  factory SessionCommandMessage.fromJson(Map<String, dynamic> json) {
    return SessionCommandMessage(
      requestId: json['request-id'] as String,
      command: json['command'] as String,
      data: Map<String, dynamic>.from(
        json['data'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Abort message (client → server)
class AbortMessage implements ClientMessage {
  @override
  String get type => 'abort';
}

/// Command result event (server -> requesting client only)
class CommandResultEvent {
  final String requestId;
  final String command;
  final bool success;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  final String? errorCode;
  final DateTime timestamp;

  CommandResultEvent({
    required this.requestId,
    required this.command,
    required this.success,
    this.result,
    this.errorMessage,
    this.errorCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': 'command-result',
    'timestamp': timestamp.toIso8601String(),
    'data': {
      'request-id': requestId,
      'command': command,
      'success': success,
      if (result != null) 'result': result,
      if (errorMessage != null)
        'error': {
          'message': errorMessage,
          if (errorCode != null) 'code': errorCode,
        },
    },
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Sequence number generator for session events
class SequenceGenerator {
  int _seq = 0;

  int next() => ++_seq;
  int get current => _seq;
}

/// WebSocket event for session streaming (Phase 2.5 format with kebab-case)
class SessionEvent {
  final int seq;
  final String eventId;
  final String type;
  final String agentId;
  final String agentType;
  final String? agentName;
  final String? taskName;
  final bool? isPartial;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  SessionEvent({
    required this.seq,
    required this.eventId,
    required this.type,
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    this.isPartial,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'event-id': eventId,
    'type': type,
    'agent-id': agentId,
    'agent-type': agentType,
    if (agentName != null) 'agent-name': agentName,
    if (taskName != null) 'task-name': taskName,
    if (isPartial != null) 'is-partial': isPartial,
    if (data != null) 'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  /// Create a message event (streaming chunk or complete message)
  factory SessionEvent.message({
    required int seq,
    required String eventId,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String role,
    required String content,
    required bool isPartial,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: eventId,
      type: 'message',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      isPartial: isPartial,
      data: {'role': role, 'content': content},
    );
  }

  /// Create a tool-use event
  factory SessionEvent.toolUse({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String toolUseId,
    required String toolName,
    required Map<String, dynamic> toolInput,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'tool-use',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {
        'tool-use-id': toolUseId,
        'tool-name': toolName,
        'tool-input': toolInput,
      },
    );
  }

  /// Create a tool-result event
  factory SessionEvent.toolResult({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String toolUseId,
    required String toolName,
    required dynamic result,
    required bool isError,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'tool-result',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {
        'tool-use-id': toolUseId,
        'tool-name': toolName,
        'result': result,
        'is-error': isError,
      },
    );
  }

  /// Create a done event
  factory SessionEvent.done({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    String reason = 'complete',
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'done',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {'reason': reason},
    );
  }

  /// Create a status event
  factory SessionEvent.status({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String status,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'status',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {'status': status},
    );
  }

  /// Create an error event
  factory SessionEvent.error({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String message,
    String? code,
    Map<String, dynamic>? originalMessage,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'error',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {
        'message': message,
        if (code != null) 'code': code,
        if (originalMessage != null) 'original-message': originalMessage,
      },
    );
  }

  /// Create an agent-spawned event
  factory SessionEvent.agentSpawned({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    required String spawnedBy,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'agent-spawned',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      data: {'spawned-by': spawnedBy},
    );
  }

  /// Create an agent-terminated event
  factory SessionEvent.agentTerminated({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String terminatedBy,
    String? reason,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'agent-terminated',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {
        'terminated-by': terminatedBy,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Create a permission-request event
  factory SessionEvent.permissionRequest({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String requestId,
    required Map<String, dynamic> tool,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'permission-request',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {'request-id': requestId, 'tool': tool},
    );
  }

  /// Create an ask-user-question event
  factory SessionEvent.askUserQuestion({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
    required String requestId,
    required List<Map<String, dynamic>> questions,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'ask-user-question',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {'request-id': requestId, 'questions': questions},
    );
  }

  /// Create an aborted event
  factory SessionEvent.aborted({
    required int seq,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
  }) {
    return SessionEvent(
      seq: seq,
      eventId: const Uuid().v4(),
      type: 'aborted',
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      data: {'reason': 'aborted'},
    );
  }
}

/// Connected event (special format without seq)
class ConnectedEvent {
  final String sessionId;
  final String mainAgentId;
  final int lastSeq;
  final List<AgentInfo> agents;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  ConnectedEvent({
    required this.sessionId,
    required this.mainAgentId,
    required this.lastSeq,
    required this.agents,
    required this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': 'connected',
    'session-id': sessionId,
    'main-agent-id': mainAgentId,
    'last-seq': lastSeq,
    'agents': agents.map((a) => a.toJson()).toList(),
    'metadata': metadata,
    'timestamp': timestamp.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Agent info for connected event
class AgentInfo {
  final String id;
  final String type;
  final String name;

  AgentInfo({required this.id, required this.type, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'name': name};
}

/// History event (special format without seq)
class HistoryEvent {
  final int lastSeq;
  final List<Map<String, dynamic>> events;
  final DateTime timestamp;

  HistoryEvent({
    required this.lastSeq,
    required this.events,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': 'history',
    'last-seq': lastSeq,
    'timestamp': timestamp.toIso8601String(),
    'data': {'events': events},
  };

  String toJsonString() => jsonEncode(toJson());
}
