import 'dart:convert';

/// Base class for daemon events received over the daemon WebSocket.
sealed class DaemonEvent {
  String get type;

  static DaemonEvent fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'session-created' => DaemonSessionCreatedEvent.fromJson(json),
      'session-stopped' => DaemonSessionStoppedEvent.fromJson(json),
      'session-health' => DaemonSessionHealthEvent.fromJson(json),
      'session-seen' => DaemonSessionSeenEvent.fromJson(json),
      'daemon-status' => DaemonStatusEvent.fromJson(json),
      _ => throw ArgumentError('Unknown daemon event type: $type'),
    };
  }

  static DaemonEvent fromJsonString(String jsonString) {
    return fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// Event emitted when a new session is created.
class DaemonSessionCreatedEvent extends DaemonEvent {
  @override
  final String type = 'session-created';

  final String sessionId;
  final String workingDirectory;
  final String wsUrl;
  final String httpUrl;
  final int port;
  final DateTime createdAt;

  DaemonSessionCreatedEvent({
    required this.sessionId,
    required this.workingDirectory,
    required this.wsUrl,
    required this.httpUrl,
    required this.port,
    required this.createdAt,
  });

  factory DaemonSessionCreatedEvent.fromJson(Map<String, dynamic> json) {
    return DaemonSessionCreatedEvent(
      sessionId: json['session-id'] as String,
      workingDirectory: json['working-directory'] as String,
      wsUrl: json['ws-url'] as String,
      httpUrl: json['http-url'] as String,
      port: json['port'] as int,
      createdAt: DateTime.parse(json['created-at'] as String),
    );
  }
}

/// Event emitted when a session is stopped.
class DaemonSessionStoppedEvent extends DaemonEvent {
  @override
  final String type = 'session-stopped';

  final String sessionId;
  final String? reason;
  final int? exitCode;

  DaemonSessionStoppedEvent({
    required this.sessionId,
    this.reason,
    this.exitCode,
  });

  factory DaemonSessionStoppedEvent.fromJson(Map<String, dynamic> json) {
    return DaemonSessionStoppedEvent(
      sessionId: json['session-id'] as String,
      reason: json['reason'] as String?,
      exitCode: json['exit-code'] as int?,
    );
  }
}

/// Event emitted when session health status changes.
class DaemonSessionHealthEvent extends DaemonEvent {
  @override
  final String type = 'session-health';

  final String sessionId;
  final String state;
  final String? error;

  DaemonSessionHealthEvent({
    required this.sessionId,
    required this.state,
    this.error,
  });

  factory DaemonSessionHealthEvent.fromJson(Map<String, dynamic> json) {
    return DaemonSessionHealthEvent(
      sessionId: json['session-id'] as String,
      state: json['state'] as String,
      error: json['error'] as String?,
    );
  }
}

/// Event emitted when a session is marked as seen by a user.
class DaemonSessionSeenEvent extends DaemonEvent {
  @override
  final String type = 'session-seen';

  final String sessionId;
  final DateTime lastSeenAt;

  DaemonSessionSeenEvent({
    required this.sessionId,
    required this.lastSeenAt,
  });

  factory DaemonSessionSeenEvent.fromJson(Map<String, dynamic> json) {
    return DaemonSessionSeenEvent(
      sessionId: json['session-id'] as String,
      lastSeenAt: DateTime.parse(json['last-seen-at'] as String),
    );
  }
}

/// Event emitted with daemon status (sent on WebSocket connect).
class DaemonStatusEvent extends DaemonEvent {
  @override
  final String type = 'daemon-status';

  final int sessionCount;
  final DateTime startedAt;
  final String version;

  DaemonStatusEvent({
    required this.sessionCount,
    required this.startedAt,
    required this.version,
  });

  factory DaemonStatusEvent.fromJson(Map<String, dynamic> json) {
    return DaemonStatusEvent(
      sessionCount: json['session-count'] as int,
      startedAt: DateTime.parse(json['started-at'] as String),
      version: json['version'] as String,
    );
  }
}
