/// Shared event infrastructure for session implementations.
///
/// Both local and remote session implementations need an identical
/// event pipeline: StreamController -> BufferedEventStream -> ConversationStateManager.
/// This component owns that pipeline so each session can compose with it
/// instead of duplicating the setup.
library;

import 'dart:async';

import '../session.dart';
import '../utils/buffered_event_stream.dart';
import '../events/vide_event.dart';
import 'conversation_state.dart';

/// Owns the event pipeline and state management shared by all session implementations.
///
/// Creates and wires:
/// 1. A broadcast [StreamController] for emitting [VideEvent]s
/// 2. A [BufferedEventStream] that replays events to late subscribers
/// 3. A [ConversationStateManager] that accumulates events into renderable state
/// 4. A [VideState] stream built from a session-supplied builder callback
class SessionEventHub {
  /// The underlying controller for emitting events.
  final StreamController<VideEvent> controller;

  /// Buffered stream that replays events to the first subscriber.
  late final BufferedEventStream<VideEvent> bufferedEvents;

  /// Accumulates events into a renderable conversation state.
  final ConversationStateManager conversationStateManager;

  /// Unified state stream controller.
  final StreamController<VideState> _stateController =
      StreamController<VideState>.broadcast();

  /// Whether the session has been disposed.
  bool _disposed = false;

  /// Session-supplied callback that builds the current state snapshot.
  ///
  /// Set via [setStateBuilder] before calling [emitState].
  VideState Function()? _stateBuilder;

  /// Creates the event pipeline.
  ///
  /// [syncController] should be `true` for local sessions where synchronous
  /// event delivery is needed, and `false` (default) for remote sessions.
  SessionEventHub({bool syncController = false})
    : controller = StreamController<VideEvent>.broadcast(sync: syncController),
      conversationStateManager = ConversationStateManager() {
    bufferedEvents = BufferedEventStream(controller.stream);
    controller.stream.listen(conversationStateManager.handleEvent);
  }

  /// Whether the hub (and its owning session) has been disposed.
  bool get isDisposed => _disposed;

  /// The public event stream (buffered for late subscribers).
  Stream<VideEvent> get events => bufferedEvents.stream;

  /// The raw controller stream (for internal subscriptions that need
  /// events before the BufferedEventStream wrapper).
  Stream<VideEvent> get rawStream => controller.stream;

  /// Stream of immutable state snapshots.
  Stream<VideState> get stateStream => _stateController.stream;

  /// Register the callback that builds a [VideState] snapshot.
  ///
  /// Must be called once during session initialization, before any
  /// [emitState] or [state] calls.
  void setStateBuilder(VideState Function() builder) {
    _stateBuilder = builder;
  }

  /// Build the current immutable state snapshot.
  VideState get state {
    assert(
      _stateBuilder != null,
      'setStateBuilder must be called before accessing state',
    );
    return _stateBuilder!();
  }

  /// Build a snapshot of per-agent conversation states from the conversation manager.
  ///
  /// Both session implementations need this identical logic when constructing
  /// [VideState], so it lives here to avoid duplication.
  List<AgentConversationState> get agentConversationStateSnapshot {
    return conversationStateManager.agentIds
        .map((id) => conversationStateManager.getAgentState(id))
        .whereType<AgentConversationState>()
        .toList();
  }

  /// Emit a new state snapshot to listeners.
  ///
  /// No-op if the hub has been disposed.
  void emitState() {
    if (!_disposed) {
      _stateController.add(state);
    }
  }

  /// Emit a business event to all listeners.
  void emit(VideEvent event) => controller.add(event);

  /// Emit an error to all listeners.
  void emitError(Object error) => controller.addError(error);

  /// Throws [StateError] if the session has been disposed.
  void checkNotDisposed() {
    if (_disposed) {
      throw StateError('Session has been disposed');
    }
  }

  /// Dispose all owned resources.
  void dispose() {
    _disposed = true;
    conversationStateManager.dispose();
    bufferedEvents.dispose();
    controller.close();
    _stateController.close();
  }
}
