import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

class FakeMcpServer extends McpServerBase {
  final bool _fakeIsRunning;
  final String _fakeUrl;

  FakeMcpServer({
    required super.name,
    super.version = '0.0.1',
    bool isRunning = true,
    String url = 'http://localhost:1234/mcp',
  }) : _fakeIsRunning = isRunning,
       _fakeUrl = url;

  @override
  bool get isRunning => _fakeIsRunning;

  @override
  Map<String, dynamic> toClaudeConfig() => {'url': _fakeUrl};

  @override
  void registerTools(McpServer server) {}

  @override
  Future<void> start({int? port}) async {}

  @override
  Future<void> stop() async {}
}

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

    test('creates TOML config with running server entries', () async {
      final server = FakeMcpServer(
        name: 'test-server',
        url: 'http://localhost:5678/mcp',
      );

      await CodexMcpRegistry.writeConfig(
        mcpServers: [server],
        workingDirectory: tempDir.path,
      );

      final configFile = File('${tempDir.path}/.codex/config.toml');
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content, contains('[mcp_servers.test_server]'));
      expect(content, contains('url = "http://localhost:5678/mcp"'));
    });

    test('skips non-running servers', () async {
      final running = FakeMcpServer(
        name: 'running',
        url: 'http://localhost:1111/mcp',
      );
      final stopped = FakeMcpServer(
        name: 'stopped',
        isRunning: false,
        url: 'http://localhost:2222/mcp',
      );

      await CodexMcpRegistry.writeConfig(
        mcpServers: [running, stopped],
        workingDirectory: tempDir.path,
      );

      final content = File(
        '${tempDir.path}/.codex/config.toml',
      ).readAsStringSync();
      expect(content, contains('[mcp_servers.running]'));
      expect(content, isNot(contains('[mcp_servers.stopped]')));
    });

    test('writes multiple server entries', () async {
      final servers = [
        FakeMcpServer(name: 'alpha', url: 'http://localhost:1001/mcp'),
        FakeMcpServer(name: 'beta', url: 'http://localhost:1002/mcp'),
      ];

      await CodexMcpRegistry.writeConfig(
        mcpServers: servers,
        workingDirectory: tempDir.path,
      );

      final content = File(
        '${tempDir.path}/.codex/config.toml',
      ).readAsStringSync();
      expect(content, contains('[mcp_servers.alpha]'));
      expect(content, contains('url = "http://localhost:1001/mcp"'));
      expect(content, contains('[mcp_servers.beta]'));
      expect(content, contains('url = "http://localhost:1002/mcp"'));
    });

    test('sanitizes server name with special characters', () async {
      final server = FakeMcpServer(
        name: 'my-server.v2!',
        url: 'http://localhost:9999/mcp',
      );

      await CodexMcpRegistry.writeConfig(
        mcpServers: [server],
        workingDirectory: tempDir.path,
      );

      final content = File(
        '${tempDir.path}/.codex/config.toml',
      ).readAsStringSync();
      expect(content, contains('[mcp_servers.my_server_v2_]'));
    });
  });

  group('CodexMcpRegistry backup/restore', () {
    test('backs up existing config and restores on cleanUp', () async {
      final codexDir = Directory('${tempDir.path}/.codex');
      codexDir.createSync();
      final configFile = File('${codexDir.path}/config.toml');
      const originalContent = '# original user config\nkey = "value"\n';
      configFile.writeAsStringSync(originalContent);

      final server = FakeMcpServer(name: 'test');

      await CodexMcpRegistry.writeConfig(
        mcpServers: [server],
        workingDirectory: tempDir.path,
      );

      // Config should be overwritten
      expect(configFile.readAsStringSync(), isNot(equals(originalContent)));
      expect(configFile.readAsStringSync(), contains('[mcp_servers.test]'));

      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);

      // Original content should be restored
      expect(configFile.readAsStringSync(), equals(originalContent));
    });

    test('deletes config on cleanUp when no pre-existing file', () async {
      final server = FakeMcpServer(name: 'ephemeral');

      await CodexMcpRegistry.writeConfig(
        mcpServers: [server],
        workingDirectory: tempDir.path,
      );

      final configFile = File('${tempDir.path}/.codex/config.toml');
      expect(configFile.existsSync(), isTrue);

      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);

      expect(configFile.existsSync(), isFalse);
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
      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);
    });

    test('does nothing if .codex dir does not exist', () async {
      await CodexMcpRegistry.cleanUp(workingDirectory: tempDir.path);
      expect(Directory('${tempDir.path}/.codex').existsSync(), isFalse);
    });
  });
}
