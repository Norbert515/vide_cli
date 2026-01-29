import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';

void main() {
  group('PermissionStateNotifier', () {
    late PermissionStateNotifier notifier;

    setUp(() {
      notifier = PermissionStateNotifier();
    });

    test('starts with empty state', () {
      expect(notifier.state.current, isNull);
      expect(notifier.state.queueLength, equals(0));
    });

    test('enqueueRequest adds first request as current', () {
      final request = PermissionRequest(
        requestId: 'req-1',
        toolName: 'Bash',
        toolInput: {'command': 'ls'},
        cwd: '/tmp',
      );

      notifier.enqueueRequest(request);

      expect(notifier.state.current, equals(request));
      expect(notifier.state.queueLength, equals(1));
    });

    test('enqueueRequest queues multiple requests', () {
      final request1 = PermissionRequest(
        requestId: 'req-1',
        toolName: 'Bash',
        toolInput: {'command': 'ls'},
        cwd: '/tmp',
      );
      final request2 = PermissionRequest(
        requestId: 'req-2',
        toolName: 'Write',
        toolInput: {'file_path': '/tmp/test.txt'},
        cwd: '/tmp',
      );

      notifier.enqueueRequest(request1);
      notifier.enqueueRequest(request2);

      expect(notifier.state.current?.requestId, equals('req-1'));
      expect(notifier.state.queueLength, equals(2));
    });

    test('dequeueRequest removes current and shows next', () {
      final request1 = PermissionRequest(
        requestId: 'req-1',
        toolName: 'Bash',
        toolInput: {'command': 'ls'},
        cwd: '/tmp',
      );
      final request2 = PermissionRequest(
        requestId: 'req-2',
        toolName: 'Write',
        toolInput: {'file_path': '/tmp/test.txt'},
        cwd: '/tmp',
      );

      notifier.enqueueRequest(request1);
      notifier.enqueueRequest(request2);
      notifier.dequeueRequest();

      expect(notifier.state.current?.requestId, equals('req-2'));
      expect(notifier.state.queueLength, equals(1));
    });

    test('dequeueRequest clears state when queue is empty', () {
      final request = PermissionRequest(
        requestId: 'req-1',
        toolName: 'Bash',
        toolInput: {'command': 'ls'},
        cwd: '/tmp',
      );

      notifier.enqueueRequest(request);
      notifier.dequeueRequest();

      expect(notifier.state.current, isNull);
      expect(notifier.state.queueLength, equals(0));
    });

    test('dequeueRequest on empty queue is a no-op', () {
      notifier.dequeueRequest();

      expect(notifier.state.current, isNull);
      expect(notifier.state.queueLength, equals(0));
    });
  });

  group('AskUserQuestionStateNotifier', () {
    late AskUserQuestionStateNotifier notifier;

    setUp(() {
      notifier = AskUserQuestionStateNotifier();
    });

    test('starts with empty state', () {
      expect(notifier.state.current, isNull);
      expect(notifier.state.queueLength, equals(0));
    });

    test('enqueueRequest adds first request as current', () {
      const request = AskUserQuestionUIRequest(
        requestId: 'ask-1',
        questions: [
          AskUserQuestionData(
            question: 'What color?',
            options: [
              AskUserQuestionOptionData(label: 'Red', description: 'A red color'),
              AskUserQuestionOptionData(label: 'Blue', description: 'A blue color'),
            ],
          ),
        ],
      );

      notifier.enqueueRequest(request);

      expect(notifier.state.current, equals(request));
      expect(notifier.state.queueLength, equals(1));
    });

    test('enqueueRequest queues multiple requests', () {
      const request1 = AskUserQuestionUIRequest(
        requestId: 'ask-1',
        questions: [
          AskUserQuestionData(
            question: 'Question 1?',
            options: [
              AskUserQuestionOptionData(label: 'A', description: ''),
            ],
          ),
        ],
      );
      const request2 = AskUserQuestionUIRequest(
        requestId: 'ask-2',
        questions: [
          AskUserQuestionData(
            question: 'Question 2?',
            options: [
              AskUserQuestionOptionData(label: 'B', description: ''),
            ],
          ),
        ],
      );

      notifier.enqueueRequest(request1);
      notifier.enqueueRequest(request2);

      expect(notifier.state.current?.requestId, equals('ask-1'));
      expect(notifier.state.queueLength, equals(2));
    });

    test('dequeueRequest removes current and shows next', () {
      const request1 = AskUserQuestionUIRequest(
        requestId: 'ask-1',
        questions: [],
      );
      const request2 = AskUserQuestionUIRequest(
        requestId: 'ask-2',
        questions: [],
      );

      notifier.enqueueRequest(request1);
      notifier.enqueueRequest(request2);
      notifier.dequeueRequest();

      expect(notifier.state.current?.requestId, equals('ask-2'));
      expect(notifier.state.queueLength, equals(1));
    });

    test('dequeueRequest clears state when queue is empty', () {
      const request = AskUserQuestionUIRequest(
        requestId: 'ask-1',
        questions: [],
      );

      notifier.enqueueRequest(request);
      notifier.dequeueRequest();

      expect(notifier.state.current, isNull);
      expect(notifier.state.queueLength, equals(0));
    });
  });

  group('PermissionRequest', () {
    group('fromEvent factory', () {
      test('creates PermissionRequest from PermissionRequestEvent', () {
        final event = PermissionRequestEvent(
          agentId: 'agent-1',
          agentType: 'main',
          requestId: 'req-123',
          toolName: 'Bash',
          toolInput: {'command': 'rm -rf /'},
          inferredPattern: 'Bash(rm *)',
        );

        final request = PermissionRequest.fromEvent(event, '/home/user');

        expect(request.requestId, equals('req-123'));
        expect(request.toolName, equals('Bash'));
        expect(request.toolInput, equals({'command': 'rm -rf /'}));
        expect(request.cwd, equals('/home/user'));
        expect(request.inferredPattern, equals('Bash(rm *)'));
      });

      test('handles null inferredPattern', () {
        final event = PermissionRequestEvent(
          agentId: 'agent-1',
          agentType: 'main',
          requestId: 'req-123',
          toolName: 'Write',
          toolInput: {'file_path': '/tmp/test.txt'},
          inferredPattern: null,
        );

        final request = PermissionRequest.fromEvent(event, '/tmp');

        expect(request.inferredPattern, isNull);
      });
    });

    group('displayAction', () {
      test('formats Bash command', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'Bash',
          toolInput: {'command': 'git status'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('Run: git status'));
      });

      test('formats Write path', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'Write',
          toolInput: {'file_path': '/tmp/test.txt'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('Write: /tmp/test.txt'));
      });

      test('formats Edit path', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'Edit',
          toolInput: {'file_path': '/tmp/test.txt'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('Edit: /tmp/test.txt'));
      });

      test('formats MultiEdit path', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'MultiEdit',
          toolInput: {'file_path': '/tmp/test.txt'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('MultiEdit: /tmp/test.txt'));
      });

      test('formats WebFetch URL', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'WebFetch',
          toolInput: {'url': 'https://example.com'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('Fetch: https://example.com'));
      });

      test('formats WebSearch query', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'WebSearch',
          toolInput: {'query': 'dart testing'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('Search: dart testing'));
      });

      test('formats unknown tool', () {
        final request = PermissionRequest(
          requestId: 'req-1',
          toolName: 'CustomTool',
          toolInput: {'foo': 'bar'},
          cwd: '/tmp',
        );

        expect(request.displayAction, equals('Use CustomTool'));
      });
    });

    group('copyWith', () {
      test('overrides requestId', () {
        final original = PermissionRequest(
          requestId: 'req-1',
          toolName: 'Bash',
          toolInput: {'command': 'ls'},
          cwd: '/tmp',
        );

        final copied = original.copyWith(requestId: 'req-2');

        expect(copied.requestId, equals('req-2'));
        expect(copied.toolName, equals('Bash'));
      });

      test('overrides inferredPattern', () {
        final original = PermissionRequest(
          requestId: 'req-1',
          toolName: 'Bash',
          toolInput: {'command': 'ls'},
          cwd: '/tmp',
          inferredPattern: null,
        );

        final copied = original.copyWith(inferredPattern: 'Bash(ls)');

        expect(copied.inferredPattern, equals('Bash(ls)'));
      });

      test('preserves existing inferredPattern when not specified', () {
        final original = PermissionRequest(
          requestId: 'req-1',
          toolName: 'Bash',
          toolInput: {'command': 'ls'},
          cwd: '/tmp',
          inferredPattern: 'Bash(ls)',
        );

        final copied = original.copyWith(requestId: 'req-2');

        expect(copied.inferredPattern, equals('Bash(ls)'));
      });
    });
  });

  group('AskUserQuestionUIRequest', () {
    test('fromEvent factory creates request correctly', () {
      final event = AskUserQuestionEvent(
        agentId: 'agent-1',
        agentType: 'main',
        requestId: 'ask-123',
        questions: [
          const AskUserQuestionData(
            question: 'What framework?',
            header: 'Framework',
            multiSelect: false,
            options: [
              AskUserQuestionOptionData(
                label: 'Flutter',
                description: 'Cross-platform UI',
              ),
              AskUserQuestionOptionData(
                label: 'React',
                description: 'Web UI library',
              ),
            ],
          ),
        ],
      );

      final request = AskUserQuestionUIRequest.fromEvent(event);

      expect(request.requestId, equals('ask-123'));
      expect(request.questions.length, equals(1));
      expect(request.questions[0].question, equals('What framework?'));
      expect(request.questions[0].header, equals('Framework'));
      expect(request.questions[0].multiSelect, isFalse);
      expect(request.questions[0].options.length, equals(2));
      expect(request.questions[0].options[0].label, equals('Flutter'));
    });

    test('fromEvent handles multiple questions', () {
      final event = AskUserQuestionEvent(
        agentId: 'agent-1',
        agentType: 'main',
        requestId: 'ask-456',
        questions: [
          const AskUserQuestionData(
            question: 'Q1?',
            options: [AskUserQuestionOptionData(label: 'A', description: '')],
          ),
          const AskUserQuestionData(
            question: 'Q2?',
            multiSelect: true,
            options: [AskUserQuestionOptionData(label: 'B', description: '')],
          ),
        ],
      );

      final request = AskUserQuestionUIRequest.fromEvent(event);

      expect(request.questions.length, equals(2));
      expect(request.questions[0].multiSelect, isFalse);
      expect(request.questions[1].multiSelect, isTrue);
    });
  });
}
