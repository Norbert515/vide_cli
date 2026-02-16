import 'dart:convert';

import 'daemon_messages.dart';

/// Base class for daemon events sent over WebSocket.
sealed class DaemonEvent {
  String get type;

  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());

  static DaemonEvent fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'session-created' => SessionCreatedEvent.fromJson(json),
      'session-stopped' => SessionStoppedEvent.fromJson(json),
      'session-health' => SessionHealthEvent.fromJson(json),
      'session-seen' => SessionSeenEvent.fromJson(json),
      'daemon-status' => DaemonStatusEvent.fromJson(json),
      _ => throw ArgumentError('Unknown daemon event type: $type'),
    };
  }
}

/// Event emitted when a new session is created.
class SessionCreatedEvent extends DaemonEvent {
  @override
  final String type = 'session-created';

  final String sessionId;
  final String workingDirectory;
  final String wsUrl;
  final String httpUrl;
  final int port;
  final DateTime createdAt;

  SessionCreatedEvent({
    required this.sessionId,
    required this.workingDirectory,
    required this.wsUrl,
    required this.httpUrl,
    required this.port,
    required this.createdAt,
  });

  factory SessionCreatedEvent.fromJson(Map<String, dynamic> json) {
    return SessionCreatedEvent(
      sessionId: json['session-id'] as String,
      workingDirectory: json['working-directory'] as String,
      wsUrl: json['ws-url'] as String,
      httpUrl: json['http-url'] as String,
      port: json['port'] as int,
      createdAt: DateTime.parse(json['created-at'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'session-id': sessionId,
    'working-directory': workingDirectory,
    'ws-url': wsUrl,
    'http-url': httpUrl,
    'port': port,
    'created-at': createdAt.toIso8601String(),
  };
}

/// Event emitted when a session is stopped.
class SessionStoppedEvent extends DaemonEvent {
  @override
  final String type = 'session-stopped';

  final String sessionId;

  /// Reason for stopping: 'user-request', 'crash', 'health-check-failed'.
  final String? reason;

  /// Exit code if the process crashed.
  final int? exitCode;

  SessionStoppedEvent({required this.sessionId, this.reason, this.exitCode});

  factory SessionStoppedEvent.fromJson(Map<String, dynamic> json) {
    return SessionStoppedEvent(
      sessionId: json['session-id'] as String,
      reason: json['reason'] as String?,
      exitCode: json['exit-code'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'session-id': sessionId,
    if (reason != null) 'reason': reason,
    if (exitCode != null) 'exit-code': exitCode,
  };
}

/// Event emitted when session health status changes.
class SessionHealthEvent extends DaemonEvent {
  @override
  final String type = 'session-health';

  final String sessionId;
  final SessionProcessState state;
  final String? error;

  SessionHealthEvent({
    required this.sessionId,
    required this.state,
    this.error,
  });

  factory SessionHealthEvent.fromJson(Map<String, dynamic> json) {
    return SessionHealthEvent(
      sessionId: json['session-id'] as String,
      state: SessionProcessState.values.firstWhere(
        (e) => e.name == json['state'],
      ),
      error: json['error'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'session-id': sessionId,
    'state': state.name,
    if (error != null) 'error': error,
  };
}

/// Event emitted when a session is marked as seen by a user.
class SessionSeenEvent extends DaemonEvent {
  @override
  final String type = 'session-seen';

  final String sessionId;
  final DateTime lastSeenAt;

  SessionSeenEvent({required this.sessionId, required this.lastSeenAt});

  factory SessionSeenEvent.fromJson(Map<String, dynamic> json) {
    return SessionSeenEvent(
      sessionId: json['session-id'] as String,
      lastSeenAt: DateTime.parse(json['last-seen-at'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'session-id': sessionId,
    'last-seen-at': lastSeenAt.toIso8601String(),
  };
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

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'session-count': sessionCount,
    'started-at': startedAt.toIso8601String(),
    'version': version,
  };
}
