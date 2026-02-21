import 'package:agent_sdk/agent_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('AgentPermissionAllow', () {
    test('constructs with no arguments', () {
      const result = AgentPermissionAllow();
      expect(result.updatedInput, isNull);
      expect(result.updatedPermissions, isNull);
    });

    test('constructs with updatedInput', () {
      const result = AgentPermissionAllow(
        updatedInput: {'key': 'value'},
      );
      expect(result.updatedInput, {'key': 'value'});
      expect(result.updatedPermissions, isNull);
    });

    test('constructs with updatedPermissions', () {
      final result = AgentPermissionAllow(
        updatedPermissions: [
          {'type': 'addRules', 'rules': []},
        ],
      );
      expect(result.updatedPermissions, hasLength(1));
    });

    test('is an AgentPermissionResult', () {
      const result = AgentPermissionAllow();
      expect(result, isA<AgentPermissionResult>());
    });
  });

  group('AgentPermissionDeny', () {
    test('constructs with defaults', () {
      const result = AgentPermissionDeny();
      expect(result.message, '');
      expect(result.interrupt, false);
    });

    test('constructs with message', () {
      const result = AgentPermissionDeny(message: 'Not allowed');
      expect(result.message, 'Not allowed');
      expect(result.interrupt, false);
    });

    test('constructs with interrupt', () {
      const result = AgentPermissionDeny(
        message: 'Stop',
        interrupt: true,
      );
      expect(result.message, 'Stop');
      expect(result.interrupt, true);
    });

    test('is an AgentPermissionResult', () {
      const result = AgentPermissionDeny();
      expect(result, isA<AgentPermissionResult>());
    });
  });

  group('AgentPermissionResult sealed class', () {
    test('pattern matching works for Allow', () {
      const AgentPermissionResult result = AgentPermissionAllow();
      final label = switch (result) {
        AgentPermissionAllow() => 'allow',
        AgentPermissionDeny() => 'deny',
      };
      expect(label, 'allow');
    });

    test('pattern matching works for Deny', () {
      const AgentPermissionResult result = AgentPermissionDeny(
        message: 'no',
      );
      final label = switch (result) {
        AgentPermissionAllow() => 'allow',
        AgentPermissionDeny() => 'deny',
      };
      expect(label, 'deny');
    });

    test('destructuring in pattern matching extracts fields', () {
      const AgentPermissionResult result = AgentPermissionDeny(
        message: 'reason',
        interrupt: true,
      );
      final msg = switch (result) {
        AgentPermissionAllow() => 'allowed',
        AgentPermissionDeny(:final message) => message,
      };
      expect(msg, 'reason');
    });
  });

  group('AgentPermissionContext', () {
    test('constructs with no arguments', () {
      const context = AgentPermissionContext();
      expect(context.permissionSuggestions, isNull);
      expect(context.blockedPath, isNull);
    });

    test('constructs with fields', () {
      const context = AgentPermissionContext(
        permissionSuggestions: ['Bash(git*)'],
        blockedPath: '/some/path',
      );
      expect(context.permissionSuggestions, ['Bash(git*)']);
      expect(context.blockedPath, '/some/path');
    });
  });

  group('AgentCanUseToolCallback', () {
    test('typedef is callable and returns Future<AgentPermissionResult>', () async {
      final AgentCanUseToolCallback callback = (
        String toolName,
        Map<String, dynamic> input,
        AgentPermissionContext context,
      ) async {
        if (toolName == 'Bash') {
          return const AgentPermissionDeny(message: 'blocked');
        }
        return const AgentPermissionAllow();
      };

      final allow = await callback('Read', {}, const AgentPermissionContext());
      expect(allow, isA<AgentPermissionAllow>());

      final deny = await callback('Bash', {}, const AgentPermissionContext());
      expect(deny, isA<AgentPermissionDeny>());
      expect((deny as AgentPermissionDeny).message, 'blocked');
    });
  });
}
