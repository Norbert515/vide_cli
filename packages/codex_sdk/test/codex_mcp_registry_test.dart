import 'dart:io';

import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('codex_mcp_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('CodexMcpRegistry.writeConfig', () {
    test('does nothing when mcpServers is empty', () async {
      await CodexMcpRegistry.writeConfig(
        mcpServers: [],
        workingDirectory: tempDir.path,
      );

      final codexDir = Directory('${tempDir.path}/.codex');
      expect(codexDir.existsSync(), isFalse);
    });
  });

  group('CodexMcpRegistry.cleanUp', () {
    test('removes config.toml if it exists', () async {
      final codexDir = Directory('${tempDir.path}/.codex');
      codexDir.createSync();
      final configFile = File('${codexDir.path}/config.toml');
      configFile.writeAsStringSync('# test config');
      expect(configFile.existsSync(), isTrue);

      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);
      expect(configFile.existsSync(), isFalse);
    });

    test('does nothing if config.toml does not exist', () async {
      // Should not throw
      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);
    });

    test('does nothing if .codex dir does not exist', () async {
      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);
      expect(Directory('${tempDir.path}/.codex').existsSync(), isFalse);
    });
  });
}
