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
    // Seed from the session's authoritative event history so late-joining
    // subscribers (like this broadcaster) don't miss events that were
    // emitted before the subscription was established.
    for (final event in session.eventHistory) {
      final json = event.toJson();
      json['seq'] = _nextSeq++;
      json['event-id'] ??= _uuid.v4();
      _storedEvents.add(json);
    }
    _subscription = session.events.listen(_handleEvent);
    _log.info(
      '[${session.id}] Started broadcasting (seeded ${_storedEvents.length} events from history)',
    );
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
    final json = event.toJson();

    // Add sequence number
    json['seq'] = _nextSeq++;

    // Add event-id if not already present (MessageEvent has its own)
    json['event-id'] ??= _uuid.v4();

    // Store for history
    _storedEvents.add(json);

    // Broadcast to all connected clients.
    // Iterate a snapshot to guard against ConcurrentModificationError
    // (a client callback may unregister itself or another client).
    // Catch per-client errors so one broken WebSocket doesn't prevent
    // other clients from receiving the event.
    for (final client in List.of(_clients)) {
      try {
        client(json);
      } catch (e) {
        _log.warning('[${session.id}] Error broadcasting to client: $e');
      }
    }
  }

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
