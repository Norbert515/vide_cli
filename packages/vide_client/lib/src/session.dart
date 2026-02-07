import 'dart:async';
import 'dart:convert';

import 'package:vide_interface/vide_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Session lifecycle status.
enum SessionStatus {
  /// Session is active and connected.
  open,

  /// Session terminated normally (by client or server).
  closed,

  /// Session ended due to an error.
  error,
}

/// An active session with the vide_server.
///
/// Provides a stream of typed [VideEvent]s and methods to send messages.
class Session {
  final String id;
  final WebSocketChannel _channel;
  final StreamController<VideEvent> _eventController;
  final Map<String, Completer<Map<String, dynamic>?>> _pendingCommands = {};
  int _nextCommandId = 0;
  SessionStatus _status = SessionStatus.open;
  Object? _error;

  Session({required this.id, required WebSocketChannel channel})
    : _channel = channel,
      _eventController = StreamController<VideEvent>.broadcast() {
    _channel.stream.listen(
      (message) {
        final json = jsonDecode(message as String) as Map<String, dynamic>;
        final event = VideEvent.fromJson(json);
        if (event case CommandResultEvent e) {
          _handleCommandResult(e);
          return;
        }
        _eventController.add(event);
      },
      onError: (e) {
        _error = e;
        _status = SessionStatus.error;
        _failPendingCommands(StateError('Session stream error: $e'));
        _eventController.addError(e);
      },
      onDone: () {
        if (_status == SessionStatus.open) {
          _status = SessionStatus.closed;
        }
        _failPendingCommands(StateError('Session closed'));
        _eventController.close();
      },
    );
  }

  /// Stream of typed events from the server.
  Stream<VideEvent> get events => _eventController.stream;

  /// Current session status.
  SessionStatus get status => _status;

  /// The error that caused the session to end, if [status] is [SessionStatus.error].
  Object? get error => _error;

  /// Send a user message to the agent.
  void sendMessage(String content, {String? agentId}) {
    _send({
      'type': 'user-message',
      'content': content,
      if (agentId != null) 'agent-id': agentId,
    });
  }

  /// Respond to a permission request.
  void respondToPermission({
    required String requestId,
    required bool allow,
    String? message,
    bool remember = false,
    String? patternOverride,
  }) {
    _send({
      'type': 'permission-response',
      'request-id': requestId,
      'allow': allow,
      if (message != null) 'message': message,
      if (remember) 'remember': remember,
      if (patternOverride != null) 'pattern-override': patternOverride,
    });
  }

  /// Abort all active agents in the session.
  void abort() {
    _send({'type': 'abort'});
  }

  /// Respond to an AskUserQuestion request.
  void respondToAskUserQuestion({
    required String requestId,
    required Map<String, String> answers,
  }) {
    _send({
      'type': 'ask-user-question-response',
      'request-id': requestId,
      'answers': answers,
    });
  }

  /// Abort a specific agent.
  Future<void> abortAgent(String agentId) async {
    await _sendCommand('abort-agent', data: {'agent-id': agentId});
  }

  /// Clear conversation for an agent (or main agent if null).
  Future<void> clearConversation({String? agentId}) async {
    await _sendCommand(
      'clear-conversation',
      data: {if (agentId != null) 'agent-id': agentId},
    );
  }

  /// Update worktree path for the session.
  Future<Map<String, dynamic>?> setWorktreePath(String? path) {
    return _sendCommand('set-worktree-path', data: {'path': path});
  }

  /// Terminate an agent.
  Future<void> terminateAgent({
    required String agentId,
    required String terminatedBy,
    String? reason,
  }) async {
    await _sendCommand(
      'terminate-agent',
      data: {
        'agent-id': agentId,
        'terminated-by': terminatedBy,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Fork an agent and return the new agent ID.
  Future<String> forkAgent(String agentId, {String? name}) async {
    final result = await _sendCommand(
      'fork-agent',
      data: {'agent-id': agentId, if (name != null) 'name': name},
    );
    final newAgentId = result?['agent-id'] as String?;
    if (newAgentId == null || newAgentId.isEmpty) {
      throw StateError('Missing agent-id in fork-agent command result');
    }
    return newAgentId;
  }

  /// Spawn an agent and return the new agent ID.
  Future<String> spawnAgent({
    required String agentType,
    required String name,
    required String initialPrompt,
    required String spawnedBy,
  }) async {
    final result = await _sendCommand(
      'spawn-agent',
      data: {
        'agent-type': agentType,
        'name': name,
        'initial-prompt': initialPrompt,
        'spawned-by': spawnedBy,
      },
    );
    final newAgentId = result?['agent-id'] as String?;
    if (newAgentId == null || newAgentId.isEmpty) {
      throw StateError('Missing agent-id in spawn-agent command result');
    }
    return newAgentId;
  }

  /// Get queued message for an agent.
  Future<String?> getQueuedMessage(String agentId) async {
    final result = await _sendCommand(
      'get-queued-message',
      data: {'agent-id': agentId},
    );
    return result?['message'] as String?;
  }

  /// Clear queued message for an agent.
  Future<void> clearQueuedMessage(String agentId) async {
    await _sendCommand('clear-queued-message', data: {'agent-id': agentId});
  }

  /// Get model name for an agent.
  Future<String?> getModel(String agentId) async {
    final result = await _sendCommand('get-model', data: {'agent-id': agentId});
    return result?['model'] as String?;
  }

  /// Add an in-memory permission pattern.
  Future<void> addSessionPermissionPattern(String pattern) async {
    await _sendCommand(
      'add-session-permission-pattern',
      data: {'pattern': pattern},
    );
  }

  /// Check whether a tool call would be auto-allowed by session cache.
  Future<bool> isAllowedBySessionCache(
    String toolName,
    Map<String, dynamic> input,
  ) async {
    final result = await _sendCommand(
      'is-allowed-by-session-cache',
      data: {'tool-name': toolName, 'input': input},
    );
    return result?['allowed'] as bool? ?? false;
  }

  /// Clear in-memory permission cache.
  Future<void> clearSessionPermissionCache() async {
    await _sendCommand('clear-session-permission-cache');
  }

  void _send(Map<String, dynamic> message) {
    if (_status != SessionStatus.open) {
      throw StateError('Cannot send message on closed session');
    }
    _channel.sink.add(jsonEncode(message));
  }

  Future<Map<String, dynamic>?> _sendCommand(
    String command, {
    Map<String, dynamic>? data,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_status != SessionStatus.open) {
      throw StateError('Cannot send command on closed session');
    }

    final requestId =
        'cmd-${DateTime.now().microsecondsSinceEpoch}-${_nextCommandId++}';
    final completer = Completer<Map<String, dynamic>?>();
    _pendingCommands[requestId] = completer;

    _send({
      'type': 'session-command',
      'request-id': requestId,
      'command': command,
      if (data != null) 'data': data,
    });

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingCommands.remove(requestId);
      rethrow;
    }
  }

  void _handleCommandResult(CommandResultEvent event) {
    final completer = _pendingCommands.remove(event.requestId);
    if (completer == null) return;

    if (event.success) {
      completer.complete(event.result);
      return;
    }

    final message = event.errorMessage ?? 'Command failed: ${event.command}';
    completer.completeError(
      StateError(
        event.errorCode == null ? message : '[${event.errorCode}] $message',
      ),
    );
  }

  void _failPendingCommands(Object error) {
    if (_pendingCommands.isEmpty) return;
    final completers = _pendingCommands.values.toList();
    _pendingCommands.clear();
    for (final completer in completers) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  /// Close the session.
  Future<void> close() async {
    if (_status != SessionStatus.open) return;
    _status = SessionStatus.closed;
    _failPendingCommands(StateError('Session closed'));
    await _channel.sink.close();
  }
}
