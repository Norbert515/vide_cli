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

  /// Tracks partial message chunk indices by event-id for consolidation.
  /// When a final (non-partial) message arrives, all stored partials are
  /// replaced with a single consolidated event — keeping history compact
  /// while live clients still receive real-time streaming chunks.
  final _partialIndices = <String, List<int>>{};

  StreamSubscription<VideEvent>? _subscription;
  bool _disposed = false;

  SessionBroadcaster(this.session) {
    // Seed from the session's authoritative event history so late-joining
    // subscribers (like this broadcaster) don't miss events that were
    // emitted before the subscription was established.
    // Consolidate streaming partials during seeding to keep history compact.
    final partialsByEventId = <String, List<Map<String, dynamic>>>{};

    for (final event in session.eventHistory) {
      final json = event.toJson();
      json['seq'] = _nextSeq++;
      json['event-id'] ??= _uuid.v4();

      final eventId = json['event-id'] as String?;
      final type = json['type'] as String?;
      final isPartial = json['is-partial'] as bool? ?? false;

      if (type == 'message' && eventId != null) {
        if (isPartial) {
          partialsByEventId.putIfAbsent(eventId, () => []).add(json);
        } else {
          // Final chunk arrived — consolidate all partials into one event
          final partials = partialsByEventId.remove(eventId);
          if (partials != null && partials.isNotEmpty) {
            final content = partials
                    .map((p) =>
                        (p['data'] as Map<String, dynamic>?)?['content'] ?? '')
                    .join() +
                ((json['data'] as Map<String, dynamic>?)?['content'] ?? '');
            final data =
                Map<String, dynamic>.from(json['data'] as Map<String, dynamic>);
            data['content'] = content;
            json['data'] = data;
          }
          _storedEvents.add(json);
        }
      } else {
        _storedEvents.add(json);
      }
    }

    // Any remaining partials without a final chunk (e.g. interrupted stream)
    // — store them consolidated as-is so they're not lost.
    for (final entry in partialsByEventId.entries) {
      final partials = entry.value;
      if (partials.isEmpty) continue;
      final representative = Map<String, dynamic>.from(partials.last);
      final content = partials
          .map((p) => (p['data'] as Map<String, dynamic>?)?['content'] ?? '')
          .join();
      final data =
          Map<String, dynamic>.from(representative['data'] as Map<String, dynamic>);
      data['content'] = content;
      representative['data'] = data;
      _storedEvents.add(representative);
    }

    _subscription = session.events.listen(_handleEvent);
    _log.info(
      '[${session.id}] Started broadcasting (seeded ${_storedEvents.length} events from history)',
    );
  }

  /// Get stored events for history replay.
  /// Empty maps (from consolidated partial slots) are filtered out.
  List<Map<String, dynamic>> get history =>
      _storedEvents.where((e) => e.isNotEmpty).toList(growable: false);

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

    final eventId = json['event-id'] as String?;
    final type = json['type'] as String?;
    final isPartial = json['is-partial'] as bool? ?? false;

    // For message events, consolidate streaming partials in stored history.
    // Live clients still receive every chunk for real-time streaming.
    if (type == 'message' && eventId != null) {
      if (isPartial) {
        // Track the index of this partial in _storedEvents
        final index = _storedEvents.length;
        _storedEvents.add(json);
        _partialIndices.putIfAbsent(eventId, () => []).add(index);
      } else {
        // Final chunk — replace all stored partials with one consolidated event
        final indices = _partialIndices.remove(eventId);
        if (indices != null && indices.isNotEmpty) {
          final content = StringBuffer();
          for (final idx in indices) {
            final partial = _storedEvents[idx];
            content.write(
                (partial['data'] as Map<String, dynamic>?)?['content'] ?? '');
            // Mark partial slots as null — we'll keep the list indices stable
            _storedEvents[idx] = const <String, dynamic>{};
          }
          content.write(
              (json['data'] as Map<String, dynamic>?)?['content'] ?? '');
          final data =
              Map<String, dynamic>.from(json['data'] as Map<String, dynamic>);
          data['content'] = content.toString();
          json['data'] = data;
        }
        _storedEvents.add(json);
      }
    } else {
      _storedEvents.add(json);
    }

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
