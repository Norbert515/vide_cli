import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('CodexApprovalRequest', () {
    group('commandExecution', () {
      test('parses full params', () {
        final request = CodexApprovalRequest.commandExecution(
          requestId: 42,
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'item-1',
            'command': 'npm install',
            'cwd': '/home/user/project',
            'reason': 'Installing dependencies',
            'proposedExecpolicyAmendment': ['npm install'],
          },
        );

        expect(request.requestId, 42);
        expect(request.type, CodexApprovalType.commandExecution);
        expect(request.threadId, 'thread-1');
        expect(request.turnId, 'turn-1');
        expect(request.itemId, 'item-1');
        expect(request.command, 'npm install');
        expect(request.cwd, '/home/user/project');
        expect(request.reason, 'Installing dependencies');
        expect(request.proposedExecpolicyAmendment, ['npm install']);
      });

      test('defaults missing optional fields', () {
        final request = CodexApprovalRequest.commandExecution(
          requestId: 1,
          params: <String, dynamic>{},
        );

        expect(request.type, CodexApprovalType.commandExecution);
        expect(request.threadId, '');
        expect(request.turnId, '');
        expect(request.itemId, '');
        expect(request.command, isNull);
        expect(request.cwd, isNull);
        expect(request.reason, isNull);
        expect(request.proposedExecpolicyAmendment, isNull);
      });

      test('accepts string requestId', () {
        final request = CodexApprovalRequest.commandExecution(
          requestId: 'req-abc',
          params: {'threadId': 't', 'turnId': 'u', 'itemId': 'i'},
        );
        expect(request.requestId, 'req-abc');
      });
    });

    group('fileChange', () {
      test('parses full params', () {
        final request = CodexApprovalRequest.fileChange(
          requestId: 7,
          params: {
            'threadId': 'thread-2',
            'turnId': 'turn-2',
            'itemId': 'item-2',
            'reason': 'Creating config file',
            'grantRoot': '/home/user/project',
          },
        );

        expect(request.requestId, 7);
        expect(request.type, CodexApprovalType.fileChange);
        expect(request.threadId, 'thread-2');
        expect(request.turnId, 'turn-2');
        expect(request.itemId, 'item-2');
        expect(request.reason, 'Creating config file');
        expect(request.grantRoot, '/home/user/project');
        expect(request.command, isNull);
        expect(request.questions, isNull);
      });

      test('defaults missing optional fields', () {
        final request = CodexApprovalRequest.fileChange(
          requestId: 2,
          params: <String, dynamic>{},
        );

        expect(request.type, CodexApprovalType.fileChange);
        expect(request.threadId, '');
        expect(request.turnId, '');
        expect(request.itemId, '');
        expect(request.reason, isNull);
        expect(request.grantRoot, isNull);
      });
    });

    group('userInput', () {
      test('parses with questions', () {
        final request = CodexApprovalRequest.userInput(
          requestId: 10,
          params: {
            'threadId': 'thread-3',
            'turnId': 'turn-3',
            'itemId': 'item-3',
            'questions': [
              {'type': 'text', 'prompt': 'Enter API key'},
              {'type': 'confirm', 'prompt': 'Proceed?'},
            ],
          },
        );

        expect(request.requestId, 10);
        expect(request.type, CodexApprovalType.userInput);
        expect(request.threadId, 'thread-3');
        expect(request.questions, hasLength(2));
        expect(request.questions![0]['prompt'], 'Enter API key');
        expect(request.questions![1]['type'], 'confirm');
      });

      test('handles null questions', () {
        final request = CodexApprovalRequest.userInput(
          requestId: 11,
          params: {'threadId': 't', 'turnId': 'u', 'itemId': 'i'},
        );

        expect(request.type, CodexApprovalType.userInput);
        expect(request.questions, isNull);
      });

      test('defaults missing optional fields', () {
        final request = CodexApprovalRequest.userInput(
          requestId: 3,
          params: <String, dynamic>{},
        );

        expect(request.type, CodexApprovalType.userInput);
        expect(request.threadId, '');
        expect(request.turnId, '');
        expect(request.itemId, '');
        expect(request.questions, isNull);
      });
    });
  });

  group('CodexApprovalDecision', () {
    test('accept serializes to "accept"', () {
      expect(CodexApprovalDecision.accept.toJson(), 'accept');
    });

    test('acceptForSession serializes to "acceptForSession"', () {
      expect(
        CodexApprovalDecision.acceptForSession.toJson(),
        'acceptForSession',
      );
    });

    test('decline serializes to "decline"', () {
      expect(CodexApprovalDecision.decline.toJson(), 'decline');
    });

    test('cancel serializes to "cancel"', () {
      expect(CodexApprovalDecision.cancel.toJson(), 'cancel');
    });

    test('all values are present', () {
      expect(
        CodexApprovalDecision.values,
        containsAll([
          CodexApprovalDecision.accept,
          CodexApprovalDecision.acceptForSession,
          CodexApprovalDecision.decline,
          CodexApprovalDecision.cancel,
        ]),
      );
      expect(CodexApprovalDecision.values, hasLength(4));
    });
  });

  group('CodexApprovalType', () {
    test('has correct values', () {
      expect(
        CodexApprovalType.values,
        containsAll([
          CodexApprovalType.commandExecution,
          CodexApprovalType.fileChange,
          CodexApprovalType.userInput,
        ]),
      );
      expect(CodexApprovalType.values, hasLength(3));
    });
  });
}
