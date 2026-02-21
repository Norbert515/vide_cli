import 'package:agent_sdk/agent_sdk.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('AgentPermissionMapper', () {
    group('toClaude', () {
      test('maps AgentPermissionAllow to PermissionResultAllow', () {
        const agent = AgentPermissionAllow();
        final claude = AgentPermissionMapper.toClaude(agent);

        expect(claude, isA<PermissionResultAllow>());
        final allow = claude as PermissionResultAllow;
        expect(allow.updatedInput, isNull);
        expect(allow.updatedPermissions, isNull);
      });

      test('maps AgentPermissionAllow with updatedInput', () {
        const agent = AgentPermissionAllow(
          updatedInput: {'file_path': '/tmp/safe'},
        );
        final claude = AgentPermissionMapper.toClaude(agent);

        expect(claude, isA<PermissionResultAllow>());
        final allow = claude as PermissionResultAllow;
        expect(allow.updatedInput, {'file_path': '/tmp/safe'});
      });

      test('maps AgentPermissionDeny to PermissionResultDeny with message', () {
        const agent = AgentPermissionDeny(message: 'denied');
        final claude = AgentPermissionMapper.toClaude(agent);

        expect(claude, isA<PermissionResultDeny>());
        final deny = claude as PermissionResultDeny;
        expect(deny.message, 'denied');
        expect(deny.interrupt, false);
      });

      test('maps AgentPermissionDeny with interrupt', () {
        const agent = AgentPermissionDeny(
          message: 'stop now',
          interrupt: true,
        );
        final claude = AgentPermissionMapper.toClaude(agent);

        expect(claude, isA<PermissionResultDeny>());
        final deny = claude as PermissionResultDeny;
        expect(deny.message, 'stop now');
        expect(deny.interrupt, true);
      });
    });

    group('fromClaude', () {
      test('maps PermissionResultAllow to AgentPermissionAllow', () {
        const claude = PermissionResultAllow();
        final agent = AgentPermissionMapper.fromClaude(claude);

        expect(agent, isA<AgentPermissionAllow>());
        final allow = agent as AgentPermissionAllow;
        expect(allow.updatedInput, isNull);
        expect(allow.updatedPermissions, isNull);
      });

      test('maps PermissionResultAllow with updatedInput', () {
        const claude = PermissionResultAllow(
          updatedInput: {'command': 'ls'},
        );
        final agent = AgentPermissionMapper.fromClaude(claude);

        expect(agent, isA<AgentPermissionAllow>());
        final allow = agent as AgentPermissionAllow;
        expect(allow.updatedInput, {'command': 'ls'});
      });

      test('maps PermissionResultDeny to AgentPermissionDeny', () {
        const claude = PermissionResultDeny(message: 'not allowed');
        final agent = AgentPermissionMapper.fromClaude(claude);

        expect(agent, isA<AgentPermissionDeny>());
        final deny = agent as AgentPermissionDeny;
        expect(deny.message, 'not allowed');
        expect(deny.interrupt, false);
      });

      test('maps PermissionResultDeny with interrupt', () {
        const claude = PermissionResultDeny(
          message: 'critical',
          interrupt: true,
        );
        final agent = AgentPermissionMapper.fromClaude(claude);

        expect(agent, isA<AgentPermissionDeny>());
        final deny = agent as AgentPermissionDeny;
        expect(deny.message, 'critical');
        expect(deny.interrupt, true);
      });
    });
  });

  group('AgentPermissionContextMapper', () {
    test('maps AgentPermissionContext to ToolPermissionContext', () {
      const agent = AgentPermissionContext();
      final claude = AgentPermissionContextMapper.toClaude(agent);

      expect(claude, isA<ToolPermissionContext>());
    });

    test('maps AgentPermissionContext with fields', () {
      const agent = AgentPermissionContext(
        permissionSuggestions: ['Bash(git*)'],
        blockedPath: '/secret',
      );
      final claude = AgentPermissionContextMapper.toClaude(agent);

      expect(claude, isA<ToolPermissionContext>());
      expect(claude.permissionSuggestions, ['Bash(git*)']);
      expect(claude.blockedPath, '/secret');
    });

    test('maps ToolPermissionContext to AgentPermissionContext', () {
      const claude = ToolPermissionContext();
      final agent = AgentPermissionContextMapper.fromClaude(claude);

      expect(agent, isA<AgentPermissionContext>());
      expect(agent.permissionSuggestions, isNull);
      expect(agent.blockedPath, isNull);
    });

    test('maps ToolPermissionContext with fields', () {
      const claude = ToolPermissionContext(
        permissionSuggestions: ['Read(/tmp/*)'],
        blockedPath: '/etc/passwd',
      );
      final agent = AgentPermissionContextMapper.fromClaude(claude);

      expect(agent.permissionSuggestions, ['Read(/tmp/*)']);
      expect(agent.blockedPath, '/etc/passwd');
    });
  });
}
