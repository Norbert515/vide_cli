import 'package:logging/logging.dart';

final _log = Logger('SessionEventStore');

/// Stored event with its sequence number and JSON representation.
class StoredEvent {
  final int seq;
  final Map<String, dynamic> json;

  const StoredEvent({required this.seq, required this.json});
}

/// Stores events per session for reconnection support.
///
/// Events are stored in-memory and persist across WebSocket connections.
/// When a client reconnects, they receive the full event history.
///
/// This is a singleton service initialized at server startup.
class SessionEventStore {
  static final instance = SessionEventStore._();

  SessionEventStore._();

  /// Events stored per session ID
  final Map<String, List<StoredEvent>> _eventsBySession = {};

  /// Current sequence number per session
  final Map<String, int> _seqBySession = {};

  /// Expected next sequence number per session (for gap detection)
  final Map<String, int> _expectedNextSeq = {};

  /// Get the current sequence number for a session (0 if no events)
  int getCurrentSeq(String sessionId) {
    return _seqBySession[sessionId] ?? 0;
  }

  /// Get the next sequence number for a session
  int nextSeq(String sessionId) {
    final current = _seqBySession[sessionId] ?? 0;
    final next = current + 1;
    _seqBySession[sessionId] = next;
    return next;
  }

  /// Store an event for a session
  void storeEvent(String sessionId, int seq, Map<String, dynamic> json) {
    final events = _eventsBySession.putIfAbsent(sessionId, () => []);

    // Gap detection: check if sequence number is what we expect
    final expectedSeq = _expectedNextSeq[sessionId] ?? 1;
    if (seq != expectedSeq) {
      if (seq > expectedSeq) {
        _log.warning(
          '[Session $sessionId] Sequence gap detected: expected $expectedSeq, got $seq '
          '(${seq - expectedSeq} events missing)',
        );
      } else {
        _log.warning(
          '[Session $sessionId] Out-of-order event: expected $expectedSeq, got $seq',
        );
      }
    }

    events.add(StoredEvent(seq: seq, json: json));
    _seqBySession[sessionId] = seq;
    _expectedNextSeq[sessionId] = seq + 1;
    _log.fine('[Session $sessionId] Stored event seq=$seq type=${json['type']}');
  }

  /// Get all events for a session (for history replay)
  List<Map<String, dynamic>> getEvents(String sessionId) {
    final events = _eventsBySession[sessionId];
    if (events == null) return [];
    return events.map((e) => e.json).toList();
  }

  /// Get the last sequence number for a session
  int getLastSeq(String sessionId) {
    final events = _eventsBySession[sessionId];
    if (events == null || events.isEmpty) return 0;
    return events.last.seq;
  }

  /// Check if a session has any stored events
  bool hasEvents(String sessionId) {
    final events = _eventsBySession[sessionId];
    return events != null && events.isNotEmpty;
  }

  /// Clear events for a session (e.g., when session is deleted)
  void clearSession(String sessionId) {
    _eventsBySession.remove(sessionId);
    _seqBySession.remove(sessionId);
    _expectedNextSeq.remove(sessionId);
    _log.info('[Session $sessionId] Cleared event store');
  }

  /// Get the number of stored events for a session (for testing)
  int eventCount(String sessionId) {
    return _eventsBySession[sessionId]?.length ?? 0;
  }

  /// Get the total number of sessions with stored events (for testing)
  int get sessionCount => _eventsBySession.length;
}
