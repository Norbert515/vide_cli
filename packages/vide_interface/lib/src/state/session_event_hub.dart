/// Shared event infrastructure for session implementations.
///
/// Both local and remote session implementations need an identical
/// event pipeline: StreamController -> BufferedEventStream -> ConversationStateManager.
/// This component owns that pipeline so each session can compose with it
/// instead of duplicating the setup.
library;

import 'dart:async';

import '../utils/buffered_event_stream.dart';
import '../events/vide_event.dart';
import 'conversation_state.dart';

/// Owns the event pipeline shared by all session implementations.
///
/// Creates and wires:
/// 1. A broadcast [StreamController] for emitting [VideEvent]s
/// 2. A [BufferedEventStream] that replays events to late subscribers
/// 3. A [ConversationStateManager] that accumulates events into renderable state
class SessionEventHub {
  /// The underlying controller for emitting events.
  final StreamController<VideEvent> controller;

  /// Buffered stream that replays events to the first subscriber.
  late final BufferedEventStream<VideEvent> bufferedEvents;

  /// Accumulates events into a renderable conversation state.
  final ConversationStateManager conversationStateManager;

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

  /// The public event stream (buffered for late subscribers).
  Stream<VideEvent> get events => bufferedEvents.stream;

  /// The raw controller stream (for internal subscriptions that need
  /// events before the BufferedEventStream wrapper).
  Stream<VideEvent> get rawStream => controller.stream;

  /// Emit a business event to all listeners.
  void emit(VideEvent event) => controller.add(event);

  /// Emit an error to all listeners.
  void emitError(Object error) => controller.addError(error);

  /// Dispose all owned resources.
  void dispose() {
    conversationStateManager.dispose();
    bufferedEvents.dispose();
    controller.close();
  }
}
