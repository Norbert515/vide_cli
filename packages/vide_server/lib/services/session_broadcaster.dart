import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_core/vide_core.dart';

final _log = Logger('SessionBroadcaster');

/// Manages event storage and broadcasting for a session.
///
/// Each session has exactly one broadcaster that:
/// 1. Subscribes to VideSession.events once
/// 2. Stores events for history replay
/// 3. Broadcasts to all connected WebSocket clients
///
/// This ensures events are stored exactly once, regardless of how many
/// clients connect.
class SessionBroadcaster {
  final VideSession session;
  final _clients = <void Function(Map<String, dynamic>)>[];
  final _storedEvents = <Map<String, dynamic>>[];
  final _uuid = const Uuid();
  int _nextSeq = 1;

  StreamSubscription<VideEvent>? _subscription;
  bool _disposed = false;

  SessionBroadcaster(this.session) {
    _subscription = session.events.listen(_handleEvent);
    _log.info('[${session.id}] Started broadcasting');
  }

  /// Get stored events for history replay.
  List<Map<String, dynamic>> get history => List.unmodifiable(_storedEvents);

  /// Register a client to receive events.
  /// Returns a function to call when the client disconnects.
  void Function() addClient(void Function(Map<String, dynamic>) onEvent) {
    _clients.add(onEvent);
    _log.fine('[${session.id}] Client added, total: ${_clients.length}');

    return () {
      _clients.remove(onEvent);
      _log.fine('[${session.id}] Client removed, total: ${_clients.length}');
    };
  }

  void _handleEvent(VideEvent event) {
    final json = _mapToJson(event);
    if (json == null) return;

    // Add sequence number
    json['seq'] = _nextSeq++;

    // Add event-id if not already present (MessageEvent has its own)
    json['event-id'] ??= _uuid.v4();

    // Store for history
    _storedEvents.add(json);

    // Broadcast to all connected clients
    for (final client in _clients) {
      client(json);
    }
  }

  /// Create base event map with common attribution fields.
  Map<String, dynamic> _baseEvent(String type, VideEvent event) => {
    'type': type,
    'agent-id': event.agentId,
    'agent-type': event.agentType,
    'agent-name': event.agentName,
    'task-name': event.taskName,
    'timestamp': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic>? _mapToJson(VideEvent event) {
    switch (event) {
      case MessageEvent e:
        return _baseEvent('message', e)..addAll({
          'event-id': e.eventId,
          'data': {'role': e.role, 'content': e.content},
          'is-partial': e.isPartial,
        });

      case ToolUseEvent e:
        return _baseEvent('tool-use', e)
          ..['data'] = {
            'tool-use-id': e.toolUseId,
            'tool-name': e.toolName,
            'tool-input': e.toolInput,
          };

      case ToolResultEvent e:
        return _baseEvent('tool-result', e)
          ..['data'] = {
            'tool-use-id': e.toolUseId,
            'tool-name': e.toolName,
            'result': e.result,
            'is-error': e.isError,
          };

      case StatusEvent e:
        return _baseEvent('status', e)
          ..['data'] = {'status': _mapStatus(e.status)};

      case TurnCompleteEvent e:
        // Use 'complete' for backward compatibility with existing API
        return _baseEvent('done', e)..['data'] = {'reason': 'complete'};

      case AgentSpawnedEvent e:
        return _baseEvent('agent-spawned', e)
          ..['data'] = {'spawned-by': e.spawnedBy};

      case AgentTerminatedEvent e:
        return _baseEvent('agent-terminated', e)
          ..['data'] = {'reason': e.reason, 'terminated-by': e.terminatedBy};

      case PermissionRequestEvent e:
        return _baseEvent('permission-request', e)
          ..['data'] = {
            'request-id': e.requestId,
            'tool': {
              'name': e.toolName,
              'input': e.toolInput,
              if (e.inferredPattern != null)
                'permission-suggestions': [e.inferredPattern],
            },
          };

      case AskUserQuestionEvent e:
        return _baseEvent('ask-user-question', e)
          ..['data'] = {
            'request-id': e.requestId,
            'questions': e.questions
                .map(
                  (q) => {
                    'question': q.question,
                    'header': q.header,
                    'multi-select': q.multiSelect,
                    'options': q.options
                        .map(
                          (o) => {
                            'label': o.label,
                            'description': o.description,
                          },
                        )
                        .toList(),
                  },
                )
                .toList(),
          };

      case ErrorEvent e:
        return _baseEvent('error', e)
          ..['data'] = {'message': e.message, 'code': 'ERROR'};

      case TaskNameChangedEvent _:
        // Internal event, not sent to clients
        return null;
    }
  }

  String _mapStatus(VideAgentStatus status) => switch (status) {
    VideAgentStatus.working => 'working',
    VideAgentStatus.waitingForAgent => 'waiting-for-agent',
    VideAgentStatus.waitingForUser => 'waiting-for-user',
    VideAgentStatus.idle => 'idle',
  };

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription?.cancel();
    _clients.clear();
    _storedEvents.clear();
    _log.info('[${session.id}] Disposed');
  }
}

/// Registry of session broadcasters.
class SessionBroadcasterRegistry {
  static final instance = SessionBroadcasterRegistry._();
  SessionBroadcasterRegistry._();

  final _broadcasters = <String, SessionBroadcaster>{};

  /// Get or create a broadcaster for a session.
  SessionBroadcaster getOrCreate(VideSession session) {
    return _broadcasters.putIfAbsent(
      session.id,
      () => SessionBroadcaster(session),
    );
  }

  /// Check if a broadcaster exists for a session.
  bool has(String sessionId) => _broadcasters.containsKey(sessionId);

  /// Remove and dispose a broadcaster (when session ends).
  void remove(String sessionId) {
    _broadcasters.remove(sessionId)?.dispose();
  }
}
