import 'package:test/test.dart';

import 'e2e_test_harness.dart';

/// Find a textfield element with bounds.
Map<String, dynamic>? _findTextField(List<dynamic> elements) {
  for (final element in elements) {
    final e = element as Map<String, dynamic>;
    if (e['type'] == 'textfield' && e['bounds'] != null) return e;
  }
  return null;
}

/// Tap the text field to focus it.
Future<void> _focusTextField(E2eTestHarness harness) async {
  final elements = await harness.callExtensionExpectSuccess(
    'ext.runtime_ai_dev_tools.getActionableElements',
  );

  final elementsList = elements['elements'] as List<dynamic>;
  final textField = _findTextField(elementsList);

  String centerX, centerY;
  if (textField != null) {
    final bounds = textField['bounds'] as Map<String, dynamic>;
    centerX =
        ((bounds['x'] as num) + (bounds['width'] as num) / 2).toString();
    centerY =
        ((bounds['y'] as num) + (bounds['height'] as num) / 2).toString();
  } else {
    centerX = '200';
    centerY = '280';
  }

  await harness.callExtensionExpectSuccess(
    'ext.runtime_ai_dev_tools.tap',
    args: {'x': centerX, 'y': centerY},
  );
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

void typeTests(E2eTestHarness harness) {
  group('type', () {
    test('type text into focused TextField returns success', () async {
      await _focusTextField(harness);

      // Type text
      final typeResult = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.type',
        args: {'text': 'Hello E2E'},
      );

      expect(typeResult['status'], 'success');
      expect(typeResult['method'], isNotNull);
      expect(typeResult.containsKey('text'), isTrue);
    });

    test('type with backspace special key returns success', () async {
      await _focusTextField(harness);

      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.type',
        args: {'text': '{backspace}'},
      );

      expect(result['status'], 'success');
    });

    test('type_status returns hasActiveClient field', () async {
      final result = await harness.callExtension(
        'ext.runtime_ai_dev_tools.type_status',
      );

      expect(result.containsKey('hasActiveClient'), isTrue);
      expect(result['hasActiveClient'], isA<bool>());
    });
  });
}
