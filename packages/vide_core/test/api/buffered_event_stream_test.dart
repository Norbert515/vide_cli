import 'dart:async';

import 'package:test/test.dart';
import 'package:vide_core/src/utils/buffered_event_stream.dart';

void main() {
  group('BufferedEventStream', () {
    test('replays pre-subscription events to the first listener', () async {
      final source = StreamController<int>.broadcast();
      final buffered = BufferedEventStream<int>(source.stream);
      addTearDown(() async {
        buffered.dispose();
        await source.close();
      });

      source
        ..add(1)
        ..add(2)
        ..add(3);
      await Future<void>.delayed(Duration.zero);

      final events = <int>[];
      final sub = buffered.stream.listen(events.add);
      await Future<void>.delayed(Duration.zero);

      expect(events, equals([1, 2, 3]));
      await sub.cancel();
    });

    test('second listener receives only live events', () async {
      final source = StreamController<int>.broadcast();
      final buffered = BufferedEventStream<int>(source.stream);
      addTearDown(() async {
        buffered.dispose();
        await source.close();
      });

      source
        ..add(10)
        ..add(20);
      await Future<void>.delayed(Duration.zero);

      final first = <int>[];
      final second = <int>[];
      final firstSub = buffered.stream.listen(first.add);
      await Future<void>.delayed(Duration.zero);
      final secondSub = buffered.stream.listen(second.add);

      source.add(30);
      await Future<void>.delayed(Duration.zero);

      expect(first, equals([10, 20, 30]));
      expect(second, equals([30]));

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('replays buffered errors to the first listener', () async {
      final source = StreamController<int>.broadcast();
      final buffered = BufferedEventStream<int>(source.stream);
      addTearDown(() async {
        buffered.dispose();
        await source.close();
      });

      source.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      final errors = <Object>[];
      final sub = buffered.stream.listen((_) {}, onError: errors.add);
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      await sub.cancel();
    });

    test(
      'propagates completion when source closes before first listener',
      () async {
        final source = StreamController<int>.broadcast();
        final buffered = BufferedEventStream<int>(source.stream);
        addTearDown(buffered.dispose);

        source
          ..add(7)
          ..add(8);
        await source.close();
        await Future<void>.delayed(Duration.zero);

        final events = <int>[];
        var done = false;
        buffered.stream.listen(events.add, onDone: () => done = true);
        await Future<void>.delayed(Duration.zero);

        expect(events, equals([7, 8]));
        expect(done, isTrue);
      },
    );

    test('dispose closes the output stream', () async {
      final source = StreamController<int>.broadcast();
      final buffered = BufferedEventStream<int>(source.stream);
      addTearDown(() async {
        await source.close();
      });

      var done = false;
      buffered.stream.listen((_) {}, onDone: () => done = true);
      await Future<void>.delayed(Duration.zero);

      buffered.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });
  });
}
