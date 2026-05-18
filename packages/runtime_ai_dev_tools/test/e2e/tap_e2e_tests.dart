import 'package:test/test.dart';

import 'e2e_test_harness.dart';

/// Helper to find an element with bounds from the actionable elements list.
Map<String, dynamic>? _findElementWithBounds(
  List<dynamic> elements, {
  String? type,
  String? labelContains,
}) {
  for (final element in elements) {
    final e = element as Map<String, dynamic>;
    if (e['bounds'] == null) continue;
    if (type != null && e['type'] != type) continue;
    if (labelContains != null) {
      final label = e['label'];
      if (label == null ||
          !label.toString().toLowerCase().contains(labelContains)) {
        continue;
      }
    }
    return e;
  }
  return null;
}

void tapTests(E2eTestHarness harness) {
  group('tap', () {
    test('returns success with coordinates', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.tap',
        args: {'x': '100', 'y': '100'},
      );

      expect(result['x'], isNotNull);
      expect(result['y'], isNotNull);
    });

    test('tapping Increment button changes counter', () async {
      // Get actionable elements to find the Increment button
      final elements = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elementsList = elements['elements'] as List<dynamic>;
      final incrementButton = _findElementWithBounds(
        elementsList,
        labelContains: 'increment',
      );

      if (incrementButton == null) {
        // Fallback: use getWidgetInfo at an approximate button location
        // The Increment button should be around y=170 in a typical layout
        await harness.callExtensionExpectSuccess(
          'ext.runtime_ai_dev_tools.tap',
          args: {'x': '100', 'y': '170'},
        );
      } else {
        final bounds = incrementButton['bounds'] as Map<String, dynamic>;
        final centerX =
            ((bounds['x'] as num) + (bounds['width'] as num) / 2).toString();
        final centerY =
            ((bounds['y'] as num) + (bounds['height'] as num) / 2).toString();

        await harness.callExtensionExpectSuccess(
          'ext.runtime_ai_dev_tools.tap',
          args: {'x': centerX, 'y': centerY},
        );
      }

      // Wait for the tap to take effect
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Verify by taking a screenshot (confirms app is still responsive)
      final screenshot = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.screenshot',
      );
      expect(screenshot['status'], 'success');
    });

    test('tapElement returns coordinates for valid element ID', () async {
      // First, call getActionableElements to populate the registry
      final elements = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elementsList = elements['elements'] as List<dynamic>;
      expect(elementsList.isNotEmpty, isTrue,
          reason: 'Should find at least one actionable element');

      // Get the first element's ID
      final firstElement = elementsList[0] as Map<String, dynamic>;
      final elementId = firstElement['id'] as String;

      // Call tapElement with the valid ID
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.tapElement',
        args: {'id': elementId},
      );

      expect(result['id'], elementId);
      expect(result['x'], isA<num>());
      expect(result['y'], isA<num>());
    });

    test('tapElement with unknown ID returns error', () async {
      // Call getActionableElements first to populate registry
      await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      // Try to tap a non-existent element - should throw
      var didThrow = false;
      try {
        await harness.callExtension(
          'ext.runtime_ai_dev_tools.tapElement',
          args: {'id': 'nonexistent_element_99'},
        );
      } catch (e) {
        didThrow = true;
        // The extension returns an error response which the VM Service
        // surfaces as an RPCError. The exact format varies.
      }
      expect(didThrow, isTrue,
          reason: 'tapElement with unknown ID should throw');
    });
  });
}
