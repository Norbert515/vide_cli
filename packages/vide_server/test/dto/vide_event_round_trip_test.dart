/// Tests that VideEvent serialization round-trips are lossless.
///
/// Events go through this path in the server:
///   LocalVideSession emits VideEvent
///   → VideEvent.toJson() (broadcaster stores JSON)
///   → WebSocket sends JSON to client
///   → Client parses via VideEvent.fromJson()
///
/// Any field that is lost or corrupted in the toJson→fromJson round-trip
/// means the remote client sees a different event than the local session.
library;

import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

void main() {
  group('VideEvent toJson→fromJson round-trip', () {
    test('MessageEvent preserves all fields', () {
      final original = MessageEvent(
        agentId: 'agent-1',
        agentType: 'main',
        agentName: 'Main Agent',
        taskName: 'Fix bugs',
        eventId: 'evt-123',
        role: 'assistant',
        content: 'Hello, world!',
        isPartial: true,
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as MessageEvent;

      expect(restored.agentId, original.agentId);
      expect(restored.agentType, original.agentType);
      expect(restored.agentName, original.agentName);
      expect(restored.taskName, original.taskName);
      expect(restored.eventId, original.eventId);
      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.isPartial, original.isPartial);
    });

    test('MessageEvent with attachments preserves attachment data', () {
      final original = MessageEvent(
        agentId: 'agent-1',
        agentType: 'main',
        eventId: 'evt-456',
        role: 'user',
        content: 'Check this file',
        isPartial: false,
        attachments: [
          VideAttachment(
            type: 'image',
            filePath: '/tmp/screenshot.png',
            mimeType: 'image/png',
          ),
          VideAttachment(type: 'file', content: 'base64data=='),
        ],
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as MessageEvent;

      expect(restored.attachments, isNotNull);
      expect(restored.attachments, hasLength(2));
      expect(restored.attachments![0].type, 'image');
      expect(restored.attachments![0].filePath, '/tmp/screenshot.png');
      expect(restored.attachments![0].mimeType, 'image/png');
      expect(restored.attachments![1].type, 'file');
      expect(restored.attachments![1].content, 'base64data==');
    });

    test('StatusEvent preserves all fields', () {
      for (final status in VideAgentStatus.values) {
        final original = StatusEvent(
          agentId: 'agent-1',
          agentType: 'impl',
          agentName: 'Worker',
          status: status,
        );

        final json = original.toJson();
        final restored = VideEvent.fromJson(json) as StatusEvent;

        expect(
          restored.status,
          status,
          reason: 'Status $status should round-trip',
        );
        expect(restored.agentId, original.agentId);
        expect(restored.agentType, original.agentType);
      }
    });

    test('ToolUseEvent preserves all fields', () {
      final original = ToolUseEvent(
        agentId: 'agent-1',
        agentType: 'impl',
        toolUseId: 'tool-42',
        toolName: 'Bash',
        toolInput: {'command': 'ls -la', 'timeout': 5000},
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as ToolUseEvent;

      expect(restored.toolUseId, original.toolUseId);
      expect(restored.toolName, original.toolName);
      expect(restored.toolInput, original.toolInput);
    });

    test('ToolResultEvent preserves all fields', () {
      final original = ToolResultEvent(
        agentId: 'agent-1',
        agentType: 'impl',
        toolUseId: 'tool-42',
        toolName: 'Bash',
        result: 'file1.txt\nfile2.txt',
        isError: false,
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as ToolResultEvent;

      expect(restored.toolUseId, original.toolUseId);
      expect(restored.toolName, original.toolName);
      expect(restored.result, original.result);
      expect(restored.isError, original.isError);
    });

    test('ToolResultEvent with error preserves isError', () {
      final original = ToolResultEvent(
        agentId: 'agent-1',
        agentType: 'impl',
        toolUseId: 'tool-99',
        toolName: 'Bash',
        result: 'command not found',
        isError: true,
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as ToolResultEvent;

      expect(restored.isError, isTrue);
      expect(restored.result, 'command not found');
    });

    test('TurnCompleteEvent preserves token stats', () {
      final original = TurnCompleteEvent(
        agentId: 'agent-1',
        agentType: 'main',
        reason: 'end_turn',
        totalInputTokens: 1000,
        totalOutputTokens: 500,
        totalCacheReadInputTokens: 200,
        totalCacheCreationInputTokens: 100,
        totalCostUsd: 0.05,
        currentContextInputTokens: 800,
        currentContextCacheReadTokens: 150,
        currentContextCacheCreationTokens: 50,
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as TurnCompleteEvent;

      expect(restored.reason, original.reason);
      expect(restored.totalInputTokens, original.totalInputTokens);
      expect(restored.totalOutputTokens, original.totalOutputTokens);
      expect(
        restored.totalCacheReadInputTokens,
        original.totalCacheReadInputTokens,
      );
      expect(
        restored.totalCacheCreationInputTokens,
        original.totalCacheCreationInputTokens,
      );
      expect(restored.totalCostUsd, original.totalCostUsd);
      expect(
        restored.currentContextInputTokens,
        original.currentContextInputTokens,
      );
      expect(
        restored.currentContextCacheReadTokens,
        original.currentContextCacheReadTokens,
      );
      expect(
        restored.currentContextCacheCreationTokens,
        original.currentContextCacheCreationTokens,
      );
    });

    test('AgentSpawnedEvent preserves all fields', () {
      final original = AgentSpawnedEvent(
        agentId: 'agent-2',
        agentType: 'implementer',
        agentName: 'Bug Fix',
        spawnedBy: 'agent-1',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as AgentSpawnedEvent;

      expect(restored.agentId, original.agentId);
      expect(restored.agentType, original.agentType);
      expect(restored.agentName, original.agentName);
      expect(restored.spawnedBy, original.spawnedBy);
    });

    test('AgentTerminatedEvent preserves all fields including nulls', () {
      final original = AgentTerminatedEvent(
        agentId: 'agent-2',
        agentType: 'implementer',
        agentName: 'Bug Fix',
        terminatedBy: 'agent-1',
        reason: 'Task complete',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as AgentTerminatedEvent;

      expect(restored.agentId, original.agentId);
      expect(restored.terminatedBy, original.terminatedBy);
      expect(restored.reason, original.reason);
    });

    test('AgentTerminatedEvent with null terminatedBy round-trips', () {
      final original = AgentTerminatedEvent(
        agentId: 'agent-2',
        agentType: 'implementer',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as AgentTerminatedEvent;

      expect(restored.terminatedBy, isNull);
      expect(restored.reason, isNull);
    });

    test('PermissionRequestEvent preserves tool info and inferred pattern', () {
      final original = PermissionRequestEvent(
        agentId: 'agent-1',
        agentType: 'impl',
        requestId: 'perm-1',
        toolName: 'Bash',
        toolInput: {'command': 'rm -rf /tmp/test'},
        inferredPattern: 'Bash(rm -rf:*)',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as PermissionRequestEvent;

      expect(restored.requestId, original.requestId);
      expect(restored.toolName, original.toolName);
      expect(restored.toolInput, original.toolInput);
      expect(restored.inferredPattern, original.inferredPattern);
    });

    test('PermissionResolvedEvent preserves all fields', () {
      final original = PermissionResolvedEvent(
        agentId: 'agent-1',
        agentType: 'impl',
        requestId: 'perm-1',
        allow: true,
        message: 'User approved',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as PermissionResolvedEvent;

      expect(restored.requestId, original.requestId);
      expect(restored.allow, original.allow);
      expect(restored.message, original.message);
    });

    test('AskUserQuestionEvent preserves questions structure', () {
      final original = AskUserQuestionEvent(
        agentId: 'agent-1',
        agentType: 'main',
        requestId: 'ask-1',
        questions: [
          AskUserQuestionData(
            question: 'Which library?',
            header: 'Library',
            multiSelect: false,
            options: [
              AskUserQuestionOptionData(
                label: 'React',
                description: 'Popular UI library',
              ),
              AskUserQuestionOptionData(
                label: 'Vue',
                description: 'Progressive framework',
              ),
            ],
          ),
          AskUserQuestionData(
            question: 'Which features?',
            header: 'Features',
            multiSelect: true,
            options: [
              AskUserQuestionOptionData(
                label: 'Auth',
                description: 'Authentication',
              ),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as AskUserQuestionEvent;

      expect(restored.requestId, original.requestId);
      expect(restored.questions, hasLength(2));

      // First question
      expect(restored.questions[0].question, 'Which library?');
      expect(restored.questions[0].header, 'Library');
      expect(restored.questions[0].multiSelect, isFalse);
      expect(restored.questions[0].options, hasLength(2));
      expect(restored.questions[0].options[0].label, 'React');
      expect(
        restored.questions[0].options[0].description,
        'Popular UI library',
      );
      expect(restored.questions[0].options[1].label, 'Vue');

      // Second question (multiSelect)
      expect(restored.questions[1].question, 'Which features?');
      expect(restored.questions[1].multiSelect, isTrue);
    });

    test('PlanApprovalRequestEvent preserves all fields', () {
      final original = PlanApprovalRequestEvent(
        agentId: 'agent-1',
        agentType: 'main',
        requestId: 'plan-1',
        planContent: '## Plan\n1. Do this\n2. Do that',
        allowedPrompts: [
          {'tool': 'Bash', 'prompt': 'run tests'},
        ],
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as PlanApprovalRequestEvent;

      expect(restored.requestId, original.requestId);
      expect(restored.planContent, original.planContent);
      expect(restored.allowedPrompts, isNotNull);
      expect(restored.allowedPrompts, hasLength(1));
      expect(restored.allowedPrompts![0]['tool'], 'Bash');
    });

    test('PlanApprovalResolvedEvent preserves all fields', () {
      final original = PlanApprovalResolvedEvent(
        agentId: 'agent-1',
        agentType: 'main',
        requestId: 'plan-1',
        action: 'reject',
        feedback: 'Too complex, simplify step 3',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as PlanApprovalResolvedEvent;

      expect(restored.requestId, original.requestId);
      expect(restored.action, original.action);
      expect(restored.feedback, original.feedback);
    });

    test('TaskNameChangedEvent preserves both goals', () {
      final original = TaskNameChangedEvent(
        agentId: 'agent-1',
        agentType: 'main',
        newGoal: 'Implement auth',
        previousGoal: 'Session',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as TaskNameChangedEvent;

      expect(restored.newGoal, original.newGoal);
      expect(restored.previousGoal, original.previousGoal);
    });

    test('ErrorEvent preserves message and code', () {
      final original = ErrorEvent(
        agentId: 'agent-1',
        agentType: 'main',
        message: 'Rate limit exceeded',
        code: 'RATE_LIMIT',
      );

      final json = original.toJson();
      final restored = VideEvent.fromJson(json) as ErrorEvent;

      expect(restored.message, original.message);
      expect(restored.code, original.code);
    });

    test('AbortedEvent round-trips correctly', () {
      final original = AbortedEvent(agentId: 'agent-1', agentType: 'main');

      final json = original.toJson();
      final restored = VideEvent.fromJson(json);

      expect(restored, isA<AbortedEvent>());
      expect(restored.agentId, original.agentId);
    });

    test('unknown event type produces UnknownEvent', () {
      final json = {
        'type': 'future-event-type',
        'agent-id': 'agent-1',
        'agent-type': 'main',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {'foo': 'bar'},
      };

      final event = VideEvent.fromJson(json);

      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).type, 'future-event-type');
    });
  });

  group('ErrorEvent code null handling', () {
    test('ErrorEvent with null code preserves null through round-trip', () {
      final original = ErrorEvent(
        agentId: 'agent-1',
        agentType: 'main',
        message: 'Something failed',
        // code is null
      );

      expect(original.code, isNull);

      final json = original.toJson();
      // Null code should be omitted from JSON entirely
      expect(json['data'].containsKey('code'), isFalse);

      final restored = VideEvent.fromJson(json) as ErrorEvent;
      // After round-trip, code stays null
      expect(restored.code, isNull);
    });
  });
}
