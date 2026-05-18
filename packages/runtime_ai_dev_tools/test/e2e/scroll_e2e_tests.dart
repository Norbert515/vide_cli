import 'package:test/test.dart';

import 'e2e_test_harness.dart';

void scrollTests(E2eTestHarness harness) {
  group('scroll', () {
    test('returns success with coordinates', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.scroll',
        args: {
          'startX': '200',
          'startY': '400',
          'dx': '0',
          'dy': '-100',
        },
      );

      expect(result['startX'], isA<num>());
      expect(result['startY'], isA<num>());
      expect(result['dx'], isA<num>());
      expect(result['dy'], isA<num>());
      expect(result['durationMs'], isA<num>());
    });

    test('scroll in the list area', () async {
      // The list is in the Scroll Section area. Use approximate coordinates
      // that should hit the ListView based on the layout.
      // The list starts after several sections, so use a reasonable Y offset.
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.scroll',
        args: {
          'startX': '200',
          'startY': '500',
          'dx': '0',
          'dy': '-150',
          'durationMs': '300',
        },
      );

      expect(result['status'], 'success');

      // Wait for scroll animation to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
  });
}
