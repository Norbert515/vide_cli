import 'dart:async';
import 'dart:io';

import 'package:agent_sdk/agent_sdk.dart' show AgentClient;
import 'package:claude_sdk/claude_sdk.dart' show McpServerBase;
import 'package:codex_sdk/codex_sdk.dart' show CodexAgentClient;
import 'package:mcp_dart/mcp_dart.dart' show McpServer;
import 'package:vide_core/src/claude/codex_client_factory.dart';
import 'package:vide_core/src/claude/agent_configuration.dart';
import 'package:vide_core/src/claude/claude_client_factory.dart';
import 'package:vide_core/src/mcp/mcp_server_type.dart';
import 'package:test/test.dart';

/// Calls [fn] inside a guarded zone that suppresses async errors from
/// `unawaited(client.init())` — which fails when the `codex` binary
/// is not installed. Lets the event loop drain so the error fires
/// inside the guarded zone rather than leaking into the test runner.
Future<T> _withSuppressedInitErrors<T>(T Function() fn) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () {
      completer.complete(fn());
    },
    (error, stack) {
      // Suppress ProcessException from codex app-server not being installed
    },
  );
  final result = await completer.future;
  // Let the event loop drain so the async init error fires in the guarded zone
  await Future<void>.delayed(Duration(milliseconds: 100));
  return result;
}

void main() {
  group('CodexAgentClientFactory', () {
    late Directory tempDir;
    late CodexAgentClientFactory factory;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('codex_factory_test_');
      factory = CodexAgentClientFactory(
        getWorkingDirectory: () => tempDir.path,
        createMcpServer: (_, __, ___) => _FakeMcpServer(),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('implements AgentClientFactory', () {
      expect(factory, isA<AgentClientFactory>());
    });

    test('supportsFork returns false', () {
      expect(factory.supportsFork, isFalse);
    });

    test('createForked throws UnsupportedError', () {
      expect(
        () => factory.createForked(
          agentId: 'agent-1',
          config: const AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
          ),
          resumeSessionId: 'session-1',
        ),
        throwsUnsupportedError,
      );
    });

    test('createMcpServer callback receives correct args', () async {
      final calls = <_McpServerCall>[];
      final factoryWithCapture = CodexAgentClientFactory(
        getWorkingDirectory: () => tempDir.path,
        createMcpServer: (agentId, type, projectPath) {
          calls.add(_McpServerCall(agentId, type, projectPath));
          return _FakeMcpServer();
        },
      );

      await _withSuppressedInitErrors(() {
        return factoryWithCapture.createSync(
          agentId: 'agent-1',
          config: AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
            mcpServers: [McpServerType.agent, McpServerType.askUserQuestion],
          ),
        );
      });

      expect(calls, hasLength(2));
      expect(calls[0].agentId, 'agent-1');
      expect(calls[0].type, McpServerType.agent);
      expect(calls[0].projectPath, tempDir.path);
      expect(calls[1].type, McpServerType.askUserQuestion);
    });

    test('uses workingDirectory override over default', () async {
      final overrideDir = await Directory.systemTemp.createTemp(
        'codex_override_',
      );
      addTearDown(() => overrideDir.delete(recursive: true));

      String? capturedProjectPath;
      final factoryWithCapture = CodexAgentClientFactory(
        getWorkingDirectory: () => tempDir.path,
        createMcpServer: (_, __, projectPath) {
          capturedProjectPath = projectPath;
          return _FakeMcpServer();
        },
      );

      await _withSuppressedInitErrors(() {
        return factoryWithCapture.createSync(
          agentId: 'agent-1',
          config: AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
            mcpServers: [McpServerType.agent],
          ),
          workingDirectory: overrideDir.path,
        );
      });

      expect(capturedProjectPath, overrideDir.path);
    });

    test('uses default workingDirectory when none specified', () async {
      String? capturedProjectPath;
      final factoryWithCapture = CodexAgentClientFactory(
        getWorkingDirectory: () => tempDir.path,
        createMcpServer: (_, __, projectPath) {
          capturedProjectPath = projectPath;
          return _FakeMcpServer();
        },
      );

      await _withSuppressedInitErrors(() {
        return factoryWithCapture.createSync(
          agentId: 'agent-1',
          config: AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
            mcpServers: [McpServerType.agent],
          ),
        );
      });

      expect(capturedProjectPath, tempDir.path);
    });

    test('createSync returns a CodexAgentClient', () async {
      final client = await _withSuppressedInitErrors(() {
        return factory.createSync(
          agentId: 'agent-1',
          config: const AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
          ),
        );
      });

      expect(client, isA<CodexAgentClient>());
    });

    test('createSync passes networkId and agentType without error', () async {
      final client = await _withSuppressedInitErrors(() {
        return factory.createSync(
          agentId: 'agent-42',
          config: const AgentConfiguration(
            name: 'test-agent',
            systemPrompt: 'system prompt',
            harnessConfig: {'model': 'o3-mini', 'sandbox': 'network-read'},
          ),
          networkId: 'network-123',
          agentType: 'implementer',
          workingDirectory: tempDir.path,
        );
      });

      expect(client, isA<CodexAgentClient>());
    });

    test('builds config with harnessConfig values', () async {
      final client = await _withSuppressedInitErrors(() {
        return factory.createSync(
          agentId: 'agent-1',
          config: const AgentConfiguration(
            name: 'codex-agent',
            systemPrompt: 'prompt',
            harness: 'codex-cli',
            harnessConfig: {
              'model': 'o3-mini',
              'sandbox': 'network-read',
              'approvalPolicy': 'unless-allow-listed',
            },
          ),
        );
      });

      expect(client, isA<CodexAgentClient>());
    });

    test('handles config with no mcpServers', () async {
      final client = await _withSuppressedInitErrors(() {
        return factory.createSync(
          agentId: 'agent-1',
          config: const AgentConfiguration(
            name: 'test',
            systemPrompt: 'prompt',
          ),
        );
      });

      expect(client, isA<AgentClient>());
    });

    test('handles config with empty mcpServers list', () async {
      final client = await _withSuppressedInitErrors(() {
        return factory.createSync(
          agentId: 'agent-1',
          config: const AgentConfiguration(
            name: 'test',
            systemPrompt: 'prompt',
            mcpServers: [],
          ),
        );
      });

      expect(client, isA<AgentClient>());
    });
  });
}

class _McpServerCall {
  final String agentId;
  final McpServerType type;
  final String projectPath;

  _McpServerCall(this.agentId, this.type, this.projectPath);
}

class _FakeMcpServer extends McpServerBase {
  _FakeMcpServer() : super(name: 'fake', version: '0.0.0');

  @override
  void registerTools(McpServer server) {}
}
