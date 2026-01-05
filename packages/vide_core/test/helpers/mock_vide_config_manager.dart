import 'dart:io';
import 'package:vide_core/vide_core.dart';

/// A test-friendly VideConfigManager that uses a temporary directory.
class MockVideConfigManager extends VideConfigManager {
  MockVideConfigManager({required Directory tempDir})
    : super(configRoot: tempDir.path);

  /// Create a MockVideConfigManager with a new temporary directory
  static Future<MockVideConfigManager> create() async {
    final tempDir = await Directory.systemTemp.createTemp('vide_test_');
    return MockVideConfigManager(tempDir: tempDir);
  }

  /// Get the temp directory path
  String get tempPath => configRoot;

  /// Clean up the temporary directory
  Future<void> dispose() async {
    final dir = Directory(configRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
