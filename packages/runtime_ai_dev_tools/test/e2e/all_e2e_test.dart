@Tags(['e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'e2e_test_harness.dart';
import 'screenshot_e2e_tests.dart';
import 'tap_e2e_tests.dart';
import 'type_e2e_tests.dart';
import 'scroll_e2e_tests.dart';
import 'actionable_elements_e2e_tests.dart';
import 'widget_info_e2e_tests.dart';
import 'cursor_e2e_tests.dart';

void main() {
  final harness = E2eTestHarness();

  setUpAll(() async {
    final testAppDir = _resolveTestAppDir();
    await harness.start(testAppDir: testAppDir);
  });

  tearDownAll(() async {
    await harness.stop();
  });

  screenshotTests(harness);
  tapTests(harness);
  typeTests(harness);
  scrollTests(harness);
  actionableElementsTests(harness);
  widgetInfoTests(harness);
  cursorTests(harness);
}

String _resolveTestAppDir() {
  // The test runs from packages/runtime_ai_dev_tools/
  // Test app is at test/e2e/test_app/
  final dir = Directory('test/e2e/test_app');
  if (!dir.existsSync()) {
    throw StateError('Test app directory not found at ${dir.absolute.path}');
  }
  return dir.absolute.path;
}
