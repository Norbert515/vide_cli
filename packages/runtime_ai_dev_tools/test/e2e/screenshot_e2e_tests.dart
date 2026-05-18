import 'dart:convert';

import 'package:test/test.dart';

import 'e2e_test_harness.dart';

void screenshotTests(E2eTestHarness harness) {
  group('screenshot', () {
    test('returns valid PNG with device pixel ratio', () async {
      final result = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.screenshot',
      );

      // Check image is a non-empty base64 string
      expect(result['image'], isA<String>());
      final imageStr = result['image'] as String;
      expect(imageStr.isNotEmpty, isTrue);

      // Decode and verify PNG magic bytes: 0x89 0x50 0x4E 0x47
      final bytes = base64.decode(imageStr);
      expect(bytes.length, greaterThan(4));
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x4E); // N
      expect(bytes[3], 0x47); // G

      // Check devicePixelRatio
      final dpr = result['devicePixelRatio'];
      expect(dpr, isA<num>());
      expect((dpr as num).toDouble(), greaterThan(0));
    });

    test('consecutive screenshots both succeed', () async {
      // This previously crashed due to stale overlay entries in
      // showScreenshotFlash(). The fix tracks insertion state.
      final result1 = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.screenshot',
      );
      expect(result1['image'], isA<String>());

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final result2 = await harness.callExtensionExpectSuccess(
        'ext.runtime_ai_dev_tools.screenshot',
      );
      expect(result2['image'], isA<String>());

      // Both should be valid PNGs
      final bytes1 = base64.decode(result1['image'] as String);
      final bytes2 = base64.decode(result2['image'] as String);
      expect(bytes1[0], 0x89);
      expect(bytes2[0], 0x89);
    });
  });
}
