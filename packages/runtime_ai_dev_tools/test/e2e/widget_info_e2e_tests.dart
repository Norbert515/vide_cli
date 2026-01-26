import 'package:test/test.dart';

import 'e2e_test_harness.dart';

void widgetInfoTests(E2eTestHarness harness) {
  group('getWidgetInfo', () {
    test('returns non-empty widget info with type fields', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getWidgetInfo',
        args: {'x': '200', 'y': '300'},
      );

      expect(result['position'], isNotNull);
      expect(result['widgets'], isA<List>());

      final widgets = result['widgets'] as List<dynamic>;
      expect(widgets, isNotEmpty,
          reason: 'Should find widgets at the given position');

      for (final widget in widgets) {
        final w = widget as Map<String, dynamic>;
        expect(w.containsKey('type'), isTrue,
            reason: 'Each widget should have a type field');
      }
    });

    test('consecutive getWidgetInfo calls both succeed', () async {
      // This previously crashed due to stale overlay entries in
      // showInspectionPulse(). The fix tracks insertion state.
      final result1 = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getWidgetInfo',
        args: {'x': '100', 'y': '150'},
      );
      expect(result1['widgets'], isA<List>());

      final result2 = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getWidgetInfo',
        args: {'x': '200', 'y': '300'},
      );
      expect(result2['widgets'], isA<List>());
    });
  });
}
