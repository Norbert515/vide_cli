import 'dart:async';

import 'package:test/test.dart';

/// A stream wrapper that buffers events until the first listener subscribes.
///
/// This is a copy of the private `_BufferedEventStream` class from vide_session.dart
/// for testing purposes.
class BufferedEventStream<T> {
  final Stream<T> _source;
  final List<T> _buffer = [];
  StreamSubscription<T>? _sourceSubscription;
  StreamController<T>? _outputController;
  bool _hasHadListener = false;

  BufferedEventStream(this._source) {
    // Start buffering immediately
    _sourceSubscription = _source.listen(_buffer.add);
  }

  /// The stream that replays buffered events to the first subscriber,
  /// then emits live events.
  Stream<T> get stream {
    // Create output controller lazily on first access
    _outputController ??= StreamController<T>.broadcast(
      onListen: _onFirstListen,
    );
    return _outputController!.stream;
  }

  void _onFirstListen() {
    if (_hasHadListener) return;
    _hasHadListener = true;

    // Cancel buffering subscription
    _sourceSubscription?.cancel();
    _sourceSubscription = null;

    // Replay buffered events
    for (final event in _buffer) {
      _outputController?.add(event);
    }
    _buffer.clear();

    // Switch to live mode
    _sourceSubscription = _source.listen(
      _outputController?.add,
      onError: _outputController?.addError,
      onDone: _outputController?.close,
    );
  }

  /// Expose buffer for testing
  List<T> get buffer => _buffer;

  /// Expose hasHadListener for testing
  bool get hasHadListener => _hasHadListener;

  /// Dispose of resources.
  void dispose() {
    _sourceSubscription?.cancel();
    _outputController?.close();
  }
}

void main() {
  group('BufferedEventStream', () {
    group('buffering before subscription', () {
      test('events emitted before subscription are buffered', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Emit events before anyone subscribes
        sourceController.add(1);
        sourceController.add(2);
        sourceController.add(3);

        // Allow microtasks to process
        await Future<void>.delayed(Duration.zero);

        // Events should be buffered
        expect(buffered.buffer, [1, 2, 3]);
        expect(buffered.hasHadListener, false);

        buffered.dispose();
        await sourceController.close();
      });

      test('buffered events are replayed to first subscriber', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Emit events before subscribing
        sourceController.add(1);
        sourceController.add(2);
        sourceController.add(3);

        // Allow microtasks to process
        await Future<void>.delayed(Duration.zero);

        // Subscribe and collect events
        final events = <int>[];
        buffered.stream.listen(events.add);

        // Allow replay to complete
        await Future<void>.delayed(Duration.zero);

        // Should have received all buffered events
        expect(events, [1, 2, 3]);
        expect(buffered.hasHadListener, true);

        buffered.dispose();
        await sourceController.close();
      });

      test('buffer is cleared after replay', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Emit events before subscribing
        sourceController.add(1);
        sourceController.add(2);

        await Future<void>.delayed(Duration.zero);

        // Subscribe to trigger replay
        buffered.stream.listen((_) {});

        await Future<void>.delayed(Duration.zero);

        // Buffer should be cleared
        expect(buffered.buffer, isEmpty);

        buffered.dispose();
        await sourceController.close();
      });
    });

    group('live streaming after subscription', () {
      test('events after subscription are delivered immediately', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Subscribe first
        final events = <int>[];
        buffered.stream.listen(events.add);

        await Future<void>.delayed(Duration.zero);

        // Emit events after subscription
        sourceController.add(10);
        sourceController.add(20);

        await Future<void>.delayed(Duration.zero);

        // Should have received live events
        expect(events, [10, 20]);

        buffered.dispose();
        await sourceController.close();
      });

      test('events are not duplicated (buffered then live)', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Emit events before subscribing
        sourceController.add(1);
        sourceController.add(2);

        await Future<void>.delayed(Duration.zero);

        // Subscribe
        final events = <int>[];
        buffered.stream.listen(events.add);

        await Future<void>.delayed(Duration.zero);

        // Emit more events after subscription
        sourceController.add(3);
        sourceController.add(4);

        await Future<void>.delayed(Duration.zero);

        // Should have buffered + live, no duplicates
        expect(events, [1, 2, 3, 4]);

        buffered.dispose();
        await sourceController.close();
      });
    });

    group('multiple listeners', () {
      test('second listener does not trigger replay', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Emit events before subscribing
        sourceController.add(1);
        sourceController.add(2);

        await Future<void>.delayed(Duration.zero);

        // First subscriber gets replay
        final events1 = <int>[];
        buffered.stream.listen(events1.add);

        await Future<void>.delayed(Duration.zero);

        // Second subscriber - joins late
        final events2 = <int>[];
        buffered.stream.listen(events2.add);

        await Future<void>.delayed(Duration.zero);

        // Emit new events
        sourceController.add(3);

        await Future<void>.delayed(Duration.zero);

        // First listener got replay + live
        expect(events1, [1, 2, 3]);

        // Second listener only got live events after joining
        expect(events2, [3]);

        buffered.dispose();
        await sourceController.close();
      });

      test('all listeners receive live events', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Subscribe two listeners
        final events1 = <int>[];
        final events2 = <int>[];
        buffered.stream.listen(events1.add);
        buffered.stream.listen(events2.add);

        await Future<void>.delayed(Duration.zero);

        // Emit events
        sourceController.add(100);
        sourceController.add(200);

        await Future<void>.delayed(Duration.zero);

        // Both should receive
        expect(events1, [100, 200]);
        expect(events2, [100, 200]);

        buffered.dispose();
        await sourceController.close();
      });
    });

    group('error handling', () {
      test('errors from source are forwarded to listeners', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        final errors = <Object>[];
        buffered.stream.listen((_) {}, onError: errors.add);

        await Future<void>.delayed(Duration.zero);

        // Emit error
        sourceController.addError(Exception('test error'));

        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.first, isA<Exception>());

        buffered.dispose();
        await sourceController.close();
      });
    });

    group('stream completion', () {
      test('source stream close propagates to output', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        var isDone = false;
        buffered.stream.listen((_) {}, onDone: () => isDone = true);

        await Future<void>.delayed(Duration.zero);

        // Close source
        await sourceController.close();

        await Future<void>.delayed(Duration.zero);

        expect(isDone, true);

        buffered.dispose();
      });
    });

    group('dispose', () {
      test('dispose cancels subscription and closes controller', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Subscribe to create the controller
        var isDone = false;
        buffered.stream.listen((_) {}, onDone: () => isDone = true);

        await Future<void>.delayed(Duration.zero);

        // Dispose
        buffered.dispose();

        await Future<void>.delayed(Duration.zero);

        // Controller should be closed
        expect(isDone, true);

        await sourceController.close();
      });

      test('dispose works even without any listeners', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Emit some events to buffer
        sourceController.add(1);
        sourceController.add(2);

        await Future<void>.delayed(Duration.zero);

        // Dispose without ever subscribing - should not throw
        expect(() => buffered.dispose(), returnsNormally);

        await sourceController.close();
      });
    });

    group('edge cases', () {
      test('empty buffer replays nothing', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Subscribe immediately without any events
        final events = <int>[];
        buffered.stream.listen(events.add);

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
        expect(buffered.hasHadListener, true);
        expect(buffered.buffer, isEmpty);

        buffered.dispose();
        await sourceController.close();
      });

      test('accessing stream multiple times uses same controller', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Subscribe via first stream access
        final events1 = <int>[];
        buffered.stream.listen(events1.add);

        // Subscribe via second stream access
        final events2 = <int>[];
        buffered.stream.listen(events2.add);

        await Future<void>.delayed(Duration.zero);

        // Emit an event
        sourceController.add(42);

        await Future<void>.delayed(Duration.zero);

        // Both listeners should receive from same broadcast controller
        expect(events1, [42]);
        expect(events2, [42]);

        buffered.dispose();
        await sourceController.close();
      });

      test('subscription after dispose does not throw', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Access stream to create controller
        buffered.stream;

        // Dispose first
        buffered.dispose();

        // Subscribing to a closed stream is allowed (just completes immediately)
        var completedImmediately = false;
        buffered.stream.listen(
          (_) {},
          onDone: () => completedImmediately = true,
        );

        await Future<void>.delayed(Duration.zero);

        expect(completedImmediately, true);

        await sourceController.close();
      });

      test('rapid events are all captured', () async {
        final sourceController = StreamController<int>.broadcast();
        final buffered = BufferedEventStream(sourceController.stream);

        // Rapidly emit many events
        for (var i = 0; i < 100; i++) {
          sourceController.add(i);
        }

        await Future<void>.delayed(Duration.zero);

        // All should be buffered
        expect(buffered.buffer.length, 100);

        // Subscribe and verify all are replayed
        final events = <int>[];
        buffered.stream.listen(events.add);

        await Future<void>.delayed(Duration.zero);

        expect(events.length, 100);
        expect(events, List.generate(100, (i) => i));

        buffered.dispose();
        await sourceController.close();
      });
    });
  });
}
