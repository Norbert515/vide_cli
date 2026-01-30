import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart' as vc;

import '../../domain/models/agent.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/permission_request.dart';
import '../../domain/models/session.dart';
import '../../domain/models/tool_event.dart';
import '../local/settings_storage.dart';
import '../models/session_event.dart' as local;
import 'connection_repository.dart';

part 'session_repository.g.dart';

/// Exception thrown when session operations fail.
class SessionException implements Exception {
  final String message;
  final Object? cause;

  SessionException(this.message, {this.cause});

  @override
  String toString() => 'SessionException: $message';
}

/// State for the session repository.
class SessionState {
  final Session? session;
  final vc.Session? videSession;
  final bool isActive;

  const SessionState({
    this.session,
    this.videSession,
    this.isActive = false,
  });

  SessionState copyWith({
    Session? session,
    vc.Session? videSession,
    bool? isActive,
  }) {
    return SessionState(
      session: session ?? this.session,
      videSession: videSession ?? this.videSession,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Repository for managing Vide sessions.
@Riverpod(keepAlive: true)
class SessionRepository extends _$SessionRepository {
  final _eventController = StreamController<local.SessionEvent>.broadcast();

  void _log(String message) {
    developer.log(message, name: 'SessionRepository');
  }

  @override
  SessionState build() {
    ref.onDispose(() {
      state.videSession?.close();
      _eventController.close();
    });
    return const SessionState();
  }

  /// Creates a new session.
  Future<Session> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
  }) async {
    _log('Creating session with message: $initialMessage');

    final connectionState = ref.read(connectionRepositoryProvider);
    if (!connectionState.isConnected || connectionState.connection == null) {
      throw SessionException('Not connected to server');
    }

    final connection = connectionState.connection!;

    // Close existing session
    close();

    // Create vide_client instance
    final videClient = vc.VideClient(
      host: connection.host,
      port: connection.port,
    );

    // Create session via vide_client (handles both REST and WebSocket)
    final videSession = await videClient.createSession(
      initialMessage: initialMessage,
      workingDirectory: workingDirectory,
      model: model,
    );

    _log('Session created: ${videSession.id}');

    // Save working directory
    final settingsStorage = ref.read(settingsStorageProvider.notifier);
    await settingsStorage.saveWorkingDirectory(workingDirectory);

    // Create local session model
    final session = Session(
      sessionId: videSession.id,
      mainAgentId: '', // Will be set when we receive the connected event
      createdAt: DateTime.now(),
      workingDirectory: workingDirectory,
      model: model,
    );

    // Listen to vide_client events and convert them
    videSession.events.listen(
      (event) {
        final converted = _convertEvent(event);
        _eventController.add(converted);
      },
      onError: (e) {
        _eventController.addError(e);
      },
    );

    state = SessionState(
      session: session,
      videSession: videSession,
      isActive: true,
    );

    return session;
  }

  /// Converts a vide_client event to the app's local SessionEvent.
  local.SessionEvent _convertEvent(vc.VideEvent event) {
    final agentId = event.agent?.id ?? '';
    final agentType = event.agent?.type ?? '';
    final agentName = event.agent?.name;
    final taskName = event.agent?.taskName;

    return switch (event) {
      vc.ConnectedEvent(:final sessionId, mainAgentId: _, :final lastSeq, :final agents) =>
        local.ConnectedEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          sessionId: sessionId,
          lastSeq: lastSeq,
          agents: agents.map((a) => Agent(
            id: a.id,
            type: a.type,
            name: a.name,
            taskName: a.taskName,
          )).toList(),
        ),
      vc.HistoryEvent(:final events) =>
        local.HistoryEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          events: events.map((e) => _convertEvent(e as vc.VideEvent)).toList(),
        ),
      vc.MessageEvent(:final role, :final content, :final isPartial) =>
        local.MessageEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          role: role == vc.MessageRole.user ? MessageRole.user : MessageRole.assistant,
          content: content,
          isPartial: isPartial,
        ),
      vc.StatusEvent(:final status) =>
        local.StatusEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          status: _convertAgentStatus(status),
        ),
      vc.ToolUseEvent(:final toolUseId, :final toolName, :final toolInput) =>
        local.ToolUseEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          toolUse: ToolUse(
            toolUseId: toolUseId,
            toolName: toolName,
            input: toolInput,
            agentId: agentId,
            agentName: agentName,
            timestamp: event.timestamp,
          ),
        ),
      vc.ToolResultEvent(:final toolUseId, :final toolName, :final result, :final isError) =>
        local.ToolResultEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          toolResult: ToolResult(
            toolUseId: toolUseId,
            toolName: toolName,
            result: result,
            isError: isError,
            timestamp: event.timestamp,
          ),
        ),
      vc.PermissionRequestEvent(:final requestId, :final tool) =>
        local.PermissionRequestEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          request: PermissionRequest(
            requestId: requestId,
            toolName: tool['name'] as String? ?? '',
            toolInput: tool['input'] as Map<String, dynamic>? ?? {},
            agentId: agentId,
            agentName: agentName,
            timestamp: event.timestamp,
          ),
        ),
      vc.PermissionTimeoutEvent(:final requestId) =>
        local.PermissionTimeoutEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          requestId: requestId,
        ),
      vc.AgentSpawnedEvent(spawnedBy: _) =>
        local.AgentSpawnedEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          agent: Agent(
            id: agentId,
            type: agentType,
            name: agentName ?? 'Agent',
            taskName: taskName,
          ),
        ),
      vc.AgentTerminatedEvent(terminatedBy: _, :final reason) =>
        local.AgentTerminatedEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          terminatedAgentId: agentId,
          reason: reason,
        ),
      vc.DoneEvent(:final reason) =>
        local.DoneEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          reason: reason,
        ),
      vc.AbortedEvent() =>
        local.AbortedEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
        ),
      vc.ErrorEvent(:final message, :final code) =>
        local.ErrorEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          code: code ?? 'unknown',
          message: message,
        ),
      vc.UnknownEvent(:final type, :final rawData) =>
        local.UnknownEvent(
          seq: event.seq ?? 0,
          eventId: event.eventId ?? '',
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
          timestamp: event.timestamp,
          type: type,
          data: rawData,
        ),
    };
  }

  AgentStatus _convertAgentStatus(vc.AgentStatus status) {
    return switch (status) {
      vc.AgentStatus.working => AgentStatus.working,
      vc.AgentStatus.waitingForAgent => AgentStatus.waitingForAgent,
      vc.AgentStatus.waitingForUser => AgentStatus.waitingForUser,
      vc.AgentStatus.idle => AgentStatus.idle,
    };
  }

  /// Stream of session events.
  Stream<local.SessionEvent> get events => _eventController.stream;

  /// Whether a session is active.
  bool get isActive => state.isActive;

  /// Gets the current session.
  Session? get session => state.session;

  /// Sends a user message.
  void sendMessage(String content, {String? model}) {
    if (state.videSession == null) {
      throw SessionException('No active session');
    }
    state.videSession!.sendMessage(content);
  }

  /// Responds to a permission request.
  void respondToPermission(String requestId, bool allow, {String? message}) {
    if (state.videSession == null) {
      throw SessionException('No active session');
    }
    state.videSession!.respondToPermission(
      requestId: requestId,
      allow: allow,
      message: message,
    );
  }

  /// Aborts all active agents.
  void abort() {
    if (state.videSession == null) {
      throw SessionException('No active session');
    }
    state.videSession!.abort();
  }

  /// Closes the current session.
  void close() {
    _log('Closing session');
    state.videSession?.close();
    state = const SessionState();
  }
}
