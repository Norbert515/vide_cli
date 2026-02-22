import 'package:claude_sdk/claude_sdk.dart' show McpServerBase;
import 'package:mcp_dart/mcp_dart.dart' show McpServer;
import 'package:vide_core/src/claude/codex_client_factory.dart';
import 'package:vide_core/src/claude/agent_configuration.dart';
import 'package:vide_core/src/claude/claude_client_factory.dart';
import 'package:vide_core/src/mcp/mcp_server_type.dart';
import 'package:test/test.dart';

void main() {
  group('CodexAgentClientFactory', () {
    test('implements AgentClientFactory', () {
      final factory = CodexAgentClientFactory(
        getWorkingDirectory: () => '/tmp',
        createMcpServer: (_, __, ___) => _FakeMcpServer(),
      );

      expect(factory, isA<AgentClientFactory>());
    });

    test('supportsFork returns false', () {
      final factory = CodexAgentClientFactory(
        getWorkingDirectory: () => '/tmp',
        createMcpServer: (_, __, ___) => _FakeMcpServer(),
      );

      expect(factory.supportsFork, isFalse);
    });

    test('createForked throws UnsupportedError', () {
      final factory = CodexAgentClientFactory(
        getWorkingDirectory: () => '/tmp',
        createMcpServer: (_, __, ___) => _FakeMcpServer(),
      );

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

    test('createMcpServer callback receives correct args', () {
      final calls = <_McpServerCall>[];
      final factory = CodexAgentClientFactory(
        getWorkingDirectory: () => '/default/dir',
        createMcpServer: (agentId, type, projectPath) {
          calls.add(_McpServerCall(agentId, type, projectPath));
          return _FakeMcpServer();
        },
      );

      // createSync will try to start the codex subprocess (and fail on CI),
      // but we can verify the MCP server callback was invoked correctly
      // by catching the async error from init()
      try {
        factory.createSync(
          agentId: 'agent-1',
          config: AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
            mcpServers: [McpServerType.agent, McpServerType.askUserQuestion],
          ),
        );
      } catch (_) {
        // Subprocess may fail, but MCP server callback should have fired
      }

      expect(calls, hasLength(2));
      expect(calls[0].agentId, 'agent-1');
      expect(calls[0].type, McpServerType.agent);
      expect(calls[0].projectPath, '/default/dir');
      expect(calls[1].type, McpServerType.askUserQuestion);
    });

    test('uses workingDirectory override over default', () {
      String? capturedProjectPath;
      final factory = CodexAgentClientFactory(
        getWorkingDirectory: () => '/default/dir',
        createMcpServer: (_, __, projectPath) {
          capturedProjectPath = projectPath;
          return _FakeMcpServer();
        },
      );

      try {
        factory.createSync(
          agentId: 'agent-1',
          config: AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
            mcpServers: [McpServerType.agent],
          ),
          workingDirectory: '/override/dir',
        );
      } catch (_) {}

      expect(capturedProjectPath, '/override/dir');
    });

    test('uses default workingDirectory when none specified', () {
      String? capturedProjectPath;
      final factory = CodexAgentClientFactory(
        getWorkingDirectory: () => '/default/dir',
        createMcpServer: (_, __, projectPath) {
          capturedProjectPath = projectPath;
          return _FakeMcpServer();
        },
      );

      try {
        factory.createSync(
          agentId: 'agent-1',
          config: AgentConfiguration(
            name: 'test',
            systemPrompt: 'test prompt',
            mcpServers: [McpServerType.agent],
          ),
        );
      } catch (_) {}

      expect(capturedProjectPath, '/default/dir');
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
