/// Tests for LocalVideSession permission handling.
///
/// Tests the full permission flow: callback creation, permission checking,
/// ask-user flow, approval, denial, remembering, and edge cases like
/// dispose while pending.
library;

import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart' as claude;
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

import '../helpers/session_test_helper.dart';

void main() {
  group('LocalVideSession permission handling', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test(
      'auto-approved tools (Read, Grep, Glob) do not emit permission events',
      () async {
        final events = h.collectEvents();

        final callback = h.session.createPermissionCallback(
          agentId: h.agentId,
          agentName: 'Main Agent',
          agentType: 'main',
          cwd: h.tempDir.path,
        );

        final result = await callback('Read', {
          'file_path': '/tmp/test.dart',
        }, VidePermissionContext());

        expect(result, isA<VidePermissionAllow>());
        final permEvents = events.whereType<PermissionRequestEvent>();
        expect(permEvents, isEmpty);
      },
    );

    test('internal MCP tools (mcp__vide-*) are auto-approved', () async {
      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final result = await callback('mcp__vide-agent__spawnAgent', {
        'agentType': 'implementer',
        'name': 'test',
        'initialPrompt': 'hi',
      }, VidePermissionContext());
      expect(result, isA<VidePermissionAllow>());
    });

    test('TodoWrite is auto-approved', () async {
      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final result = await callback('TodoWrite', {
        'todos': [],
      }, VidePermissionContext());
      expect(result, isA<VidePermissionAllow>());
    });

    test('hardcoded deny list blocks mcp__dart__analyze_files', () async {
      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final result = await callback(
        'mcp__dart__analyze_files',
        {},
        VidePermissionContext(),
      );
      expect(result, isA<VidePermissionDeny>());
    });

    test(
      'unknown tool emits PermissionRequestEvent and waits for response',
      () async {
        final events = h.collectEvents();

        final callback = h.session.createPermissionCallback(
          agentId: h.agentId,
          agentName: 'Main Agent',
          agentType: 'main',
          cwd: h.tempDir.path,
        );

        // Start the permission check in the background (it will wait for user response)
        final resultFuture = callback('Bash', {
          'command': 'rm -rf /',
        }, VidePermissionContext());

        // Allow the async permission check to complete (reads settings from disk)
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final permEvents = events.whereType<PermissionRequestEvent>().toList();
        expect(permEvents, hasLength(1));
        expect(permEvents.first.toolName, equals('Bash'));
        expect(permEvents.first.toolInput['command'], equals('rm -rf /'));
        expect(permEvents.first.requestId, isNotEmpty);

        // Now respond to allow
        h.session.respondToPermission(permEvents.first.requestId, allow: true);

        final result = await resultFuture;
        expect(result, isA<VidePermissionAllow>());
      },
    );

    test('permission denied returns VidePermissionDeny with message', () async {
      final events = h.collectEvents();

      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback('Bash', {
        'command': 'dangerous command',
      }, VidePermissionContext());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final permEvent = events.whereType<PermissionRequestEvent>().first;

      h.session.respondToPermission(
        permEvent.requestId,
        allow: false,
        message: 'User said no',
      );

      final result = await resultFuture;
      expect(result, isA<VidePermissionDeny>());
      expect((result as VidePermissionDeny).message, equals('User said no'));
    });

    test('respondToPermission emits PermissionResolvedEvent', () async {
      final events = h.collectEvents();

      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback('Write', {
        'file_path': '/tmp/x.dart',
        'content': '...',
      }, VidePermissionContext());

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final permEvent = events.whereType<PermissionRequestEvent>().first;

      h.session.respondToPermission(permEvent.requestId, allow: true);

      await resultFuture;
      await Future<void>.delayed(Duration.zero);

      final resolvedEvents = events
          .whereType<PermissionResolvedEvent>()
          .toList();
      expect(resolvedEvents, hasLength(1));
      expect(resolvedEvents.first.requestId, equals(permEvent.requestId));
      expect(resolvedEvents.first.allow, isTrue);
    });

    test('respondToPermission with unknown requestId is a no-op', () {
      // Should not throw
      h.session.respondToPermission('nonexistent-id', allow: true);
    });

    test(
      'multiple concurrent permission requests work independently',
      () async {
        final events = h.collectEvents();

        final callback = h.session.createPermissionCallback(
          agentId: h.agentId,
          agentName: 'Main Agent',
          agentType: 'main',
          cwd: h.tempDir.path,
        );

        final future1 = callback('Bash', {
          'command': 'cmd1',
        }, VidePermissionContext());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final future2 = callback('Bash', {
          'command': 'cmd2',
        }, VidePermissionContext());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final permEvents = events.whereType<PermissionRequestEvent>().toList();
        expect(permEvents, hasLength(2));

        // Deny the first, allow the second
        h.session.respondToPermission(permEvents[0].requestId, allow: false);
        h.session.respondToPermission(permEvents[1].requestId, allow: true);

        final result1 = await future1;
        final result2 = await future2;

        expect(result1, isA<VidePermissionDeny>());
        expect(result2, isA<VidePermissionAllow>());
      },
    );

    test('dispose while permission pending completes with deny', () async {
      final callback = h.session.createPermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback('Bash', {
        'command': 'long running',
      }, VidePermissionContext());
      await Future<void>.delayed(Duration.zero);

      // Dispose the session while permission is pending
      await h.session.dispose(fireEndTrigger: false);

      final result = await resultFuture;
      expect(result, isA<VidePermissionDeny>());
      expect(
        (result as VidePermissionDeny).message,
        contains('Session disposed'),
      );
    });

    test(
      'permission callback after dispose returns deny immediately',
      () async {
        // First get a callback, then dispose, then invoke callback
        final callback = h.session.createClaudePermissionCallback(
          agentId: h.agentId,
          agentName: 'Main Agent',
          agentType: 'main',
          cwd: h.tempDir.path,
        );

        await h.session.dispose(fireEndTrigger: false);

        // The callback should return deny because _disposed guard fires
        // before creating the completer.
        final result = await callback('Bash', {
          'command': 'after dispose',
        }, claude.ToolPermissionContext());

        expect(result, isA<claude.PermissionResultDeny>());
      },
    );

    test('dangerouslySkipPermissions auto-approves everything', () async {
      // Need a new harness with skip permissions enabled
      final h2 = SessionTestHarness();
      await h2.setUp(dangerouslySkipPermissions: true);

      final callback = h2.session.createPermissionCallback(
        agentId: h2.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h2.tempDir.path,
      );

      final result = await callback('Bash', {
        'command': 'rm -rf /',
      }, VidePermissionContext());

      expect(result, isA<VidePermissionAllow>());
      await h2.dispose();
    });

    test(
      'session permission cache allows previously approved patterns',
      () async {
        // Add a pattern to session cache
        await h.session.addSessionPermissionPattern('Write(/tmp/**)');

        // Now check if it's allowed
        final allowed = await h.session.isAllowedBySessionCache('Write', {
          'file_path': '/tmp/foo.dart',
          'content': 'bar',
        });
        expect(allowed, isTrue);
      },
    );

    test('clearSessionPermissionCache removes cached patterns', () async {
      await h.session.addSessionPermissionPattern('Write(/tmp/**)');
      await h.session.clearSessionPermissionCache();

      final allowed = await h.session.isAllowedBySessionCache('Write', {
        'file_path': '/tmp/foo.dart',
        'content': 'bar',
      });
      expect(allowed, isFalse);
    });
  });

  group('LocalVideSession AskUserQuestion handling', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('AskUserQuestion tool emits event and waits for response', () async {
      final events = h.collectEvents();

      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback('AskUserQuestion', {
        'questions': [
          {
            'question': 'What color?',
            'header': 'Color',
            'multiSelect': false,
            'options': [
              {'label': 'Red', 'description': 'Warm color'},
              {'label': 'Blue', 'description': 'Cool color'},
            ],
          },
        ],
      }, claude.ToolPermissionContext());

      await Future<void>.delayed(Duration.zero);

      final askEvents = events.whereType<AskUserQuestionEvent>().toList();
      expect(askEvents, hasLength(1));
      expect(askEvents.first.questions, hasLength(1));
      expect(askEvents.first.questions.first.question, equals('What color?'));
      expect(askEvents.first.questions.first.options, hasLength(2));

      // Respond
      h.session.respondToAskUserQuestion(
        askEvents.first.requestId,
        answers: {'0': 'Red'},
      );

      final result = await resultFuture;
      expect(result, isA<claude.PermissionResultAllow>());
      final allow = result as claude.PermissionResultAllow;
      expect(allow.updatedInput, isNotNull);
      expect(allow.updatedInput!['answers'], equals({'0': 'Red'}));
    });

    test('AskUserQuestion with empty questions auto-allows', () async {
      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final result = await callback('AskUserQuestion', {
        'questions': [],
      }, claude.ToolPermissionContext());

      expect(result, isA<claude.PermissionResultAllow>());
    });

    test('AskUserQuestion with null questions auto-allows', () async {
      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final result = await callback(
        'AskUserQuestion',
        {},
        claude.ToolPermissionContext(),
      );

      expect(result, isA<claude.PermissionResultAllow>());
    });

    test('dispose while AskUserQuestion pending completes with error', () async {
      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback('AskUserQuestion', {
        'questions': [
          {
            'question': 'Pick one',
            'options': [
              {'label': 'A', 'description': 'Option A'},
              {'label': 'B', 'description': 'Option B'},
            ],
          },
        ],
      }, claude.ToolPermissionContext());

      await Future<void>.delayed(Duration.zero);

      // Dispose while waiting for answer
      await h.session.dispose(fireEndTrigger: false);

      final result = await resultFuture;
      // The handler catches the StateError from the disposed completer and returns Deny
      expect(result, isA<claude.PermissionResultDeny>());
    });
  });

  group('LocalVideSession ExitPlanMode handling', () {
    late SessionTestHarness h;

    setUp(() async {
      h = SessionTestHarness();
      await h.setUp();
    });

    tearDown(() => h.dispose());

    test('ExitPlanMode emits PlanApprovalRequestEvent', () async {
      final events = h.collectEvents();

      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback(
        'ExitPlanMode',
        {},
        claude.ToolPermissionContext(),
      );

      await Future<void>.delayed(Duration.zero);

      final planEvents = events.whereType<PlanApprovalRequestEvent>().toList();
      expect(planEvents, hasLength(1));
      expect(planEvents.first.requestId, isNotEmpty);

      // Accept the plan
      h.session.respondToPlanApproval(
        planEvents.first.requestId,
        action: 'accept',
      );

      final result = await resultFuture;
      expect(result, isA<claude.PermissionResultAllow>());
    });

    test('ExitPlanMode rejection returns deny with feedback', () async {
      final events = h.collectEvents();

      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback(
        'ExitPlanMode',
        {},
        claude.ToolPermissionContext(),
      );

      await Future<void>.delayed(Duration.zero);
      final planEvent = events.whereType<PlanApprovalRequestEvent>().first;

      h.session.respondToPlanApproval(
        planEvent.requestId,
        action: 'reject',
        feedback: 'Needs more detail',
      );

      final result = await resultFuture;
      expect(result, isA<claude.PermissionResultDeny>());
      expect(
        (result as claude.PermissionResultDeny).message,
        equals('Needs more detail'),
      );
    });

    test('ExitPlanMode emits PlanApprovalResolvedEvent on response', () async {
      final events = h.collectEvents();

      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback(
        'ExitPlanMode',
        {},
        claude.ToolPermissionContext(),
      );

      await Future<void>.delayed(Duration.zero);
      final planEvent = events.whereType<PlanApprovalRequestEvent>().first;

      h.session.respondToPlanApproval(planEvent.requestId, action: 'accept');

      await resultFuture;
      await Future<void>.delayed(Duration.zero);

      final resolvedEvents = events
          .whereType<PlanApprovalResolvedEvent>()
          .toList();
      expect(resolvedEvents, hasLength(1));
      expect(resolvedEvents.first.action, equals('accept'));
    });

    test('ExitPlanMode after dispose returns deny immediately', () async {
      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      await h.session.dispose(fireEndTrigger: false);

      final result = await callback(
        'ExitPlanMode',
        {},
        claude.ToolPermissionContext(),
      );

      expect(result, isA<claude.PermissionResultDeny>());
      expect(
        (result as claude.PermissionResultDeny).message,
        contains('Session disposed'),
      );
    });

    test('dispose while ExitPlanMode pending resolves with reject', () async {
      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback(
        'ExitPlanMode',
        {},
        claude.ToolPermissionContext(),
      );

      await Future<void>.delayed(Duration.zero);

      await h.session.dispose(fireEndTrigger: false);

      // The pending plan approval gets completed with 'reject' on dispose
      final result = await resultFuture;
      // ExitPlanMode handler catches the reject and returns deny
      expect(result, isA<claude.PermissionResultDeny>());
    });

    test('respondToPlanApproval with unknown requestId is a no-op', () {
      // Should not throw
      h.session.respondToPlanApproval('nonexistent', action: 'accept');
    });

    test('ExitPlanMode with allowedPrompts passes them through', () async {
      final events = h.collectEvents();

      final callback = h.session.createClaudePermissionCallback(
        agentId: h.agentId,
        agentName: 'Main Agent',
        agentType: 'main',
        cwd: h.tempDir.path,
      );

      final resultFuture = callback('ExitPlanMode', {
        'allowedPrompts': [
          {'tool': 'Bash', 'prompt': 'run tests'},
        ],
      }, claude.ToolPermissionContext());

      await Future<void>.delayed(Duration.zero);
      final planEvent = events.whereType<PlanApprovalRequestEvent>().first;
      expect(planEvent.allowedPrompts, isNotNull);
      expect(planEvent.allowedPrompts, hasLength(1));

      h.session.respondToPlanApproval(planEvent.requestId, action: 'accept');
      await resultFuture;
    });
  });
}
