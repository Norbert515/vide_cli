import 'package:test/test.dart';

import 'e2e_test_harness.dart';

void cursorTests(E2eTestHarness harness) {
  group('cursor', () {
    test('moveCursor returns success', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.moveCursor',
        args: {'x': '200', 'y': '300'},
      );

      expect(result['x'], isA<num>());
      expect(result['y'], isA<num>());
    });

    test('consecutive moveCursor calls both succeed', () async {
      // This previously crashed due to stale overlay entries in
      // setCursorPosition(). The fix tracks insertion state.
      final result1 = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.moveCursor',
        args: {'x': '100', 'y': '100'},
      );
      expect(result1['x'], isA<num>());

      final result2 = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.moveCursor',
        args: {'x': '300', 'y': '400'},
      );
      expect(result2['x'], isA<num>());
    });

    test('getCursorPosition returns success', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getCursorPosition',
      );

      expect(result['hasPosition'], isA<bool>());
    });

    test('getCursorPosition after tap returns a result', () async {
      await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.tap',
        args: {'x': '150', 'y': '250'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getCursorPosition',
      );

      expect(result['hasPosition'], isA<bool>());
      if (result['hasPosition'] == true) {
        expect(result['x'], isA<num>());
        expect(result['y'], isA<num>());
      }
    });
  });
}
