import 'package:test/test.dart';

import 'e2e_test_harness.dart';

void actionableElementsTests(E2eTestHarness harness) {
  group('getActionableElements', () {
    test('returns non-empty list of elements', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elements = result['elements'] as List<dynamic>;
      expect(elements, isNotEmpty);
    });

    test('finds button and textfield element types', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elements = result['elements'] as List<dynamic>;
      final types = elements
          .map((e) => (e as Map<String, dynamic>)['type'] as String)
          .toSet();

      expect(types, contains('button'),
          reason: 'Should find the Increment button');
      expect(types, contains('textfield'), reason: 'Should find the TextField');
      // CheckboxListTile may be detected as 'checkbox' via semantics
      // or as 'tappable' via widget tree fallback. Accept either.
      final hasCheckboxType =
          types.contains('checkbox') || types.contains('tappable');
      expect(hasCheckboxType, isTrue,
          reason:
              'Should find checkbox/tappable elements. Found types: $types');
    });

    test('all elements have id and type fields', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elements = result['elements'] as List<dynamic>;
      for (final element in elements) {
        final e = element as Map<String, dynamic>;
        expect(e.containsKey('id'), isTrue,
            reason: 'Element should have id: $e');
        expect(e.containsKey('type'), isTrue,
            reason: 'Element should have type: $e');
      }
    });

    test('all elements have bounds with x, y, width, height', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elements = result['elements'] as List<dynamic>;

      // Both semantics and widget_tree paths should include bounds
      for (final element in elements) {
        final e = element as Map<String, dynamic>;
        expect(e['bounds'], isNotNull,
            reason: 'Element ${e['id']} should have bounds');

        final bounds = e['bounds'] as Map<String, dynamic>;
        expect(bounds.containsKey('x'), isTrue,
            reason: 'Bounds should have x: $bounds');
        expect(bounds.containsKey('y'), isTrue,
            reason: 'Bounds should have y: $bounds');
        expect(bounds.containsKey('width'), isTrue,
            reason: 'Bounds should have width: $bounds');
        expect(bounds.containsKey('height'), isTrue,
            reason: 'Bounds should have height: $bounds');
      }
    });

    test('element IDs are unique', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final elements = result['elements'] as List<dynamic>;
      final ids =
          elements.map((e) => (e as Map<String, dynamic>)['id'] as String);
      final uniqueIds = ids.toSet();

      expect(uniqueIds.length, ids.length,
          reason: 'All element IDs should be unique');
    });

    test('reports method as semantics or widget_tree', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.getActionableElements',
      );

      final method = result['method'] as String;
      expect(
        ['semantics', 'widget_tree'].contains(method),
        isTrue,
        reason: 'Method should be "semantics" or "widget_tree", got: $method',
      );
    });
  });
}
