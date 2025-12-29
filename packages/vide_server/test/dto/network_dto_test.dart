import 'dart:convert';
import 'package:test/test.dart';
import 'package:vide_server/dto/network_dto.dart';

void main() {
  group('CreateNetworkRequest', () {
    test('fromJson parses valid JSON', () {
      final json = {
        'initialMessage': 'Hello, world!',
        'workingDirectory': '/home/user/project',
      };

      final request = CreateNetworkRequest.fromJson(json);

      expect(request.initialMessage, 'Hello, world!');
      expect(request.workingDirectory, '/home/user/project');
    });

    test('toJson produces valid JSON', () {
      final request = CreateNetworkRequest(
        initialMessage: 'Test message',
        workingDirectory: '/test/path',
      );

      final json = request.toJson();

      expect(json['initialMessage'], 'Test message');
      expect(json['workingDirectory'], '/test/path');
    });
  });

  group('CreateNetworkResponse', () {
    test('toJson produces valid JSON', () {
      final createdAt = DateTime(2024, 1, 1, 12, 0);
      final response = CreateNetworkResponse(
        networkId: 'net-123',
        mainAgentId: 'agent-456',
        createdAt: createdAt,
      );

      final json = response.toJson();

      expect(json['networkId'], 'net-123');
      expect(json['mainAgentId'], 'agent-456');
      expect(json['createdAt'], createdAt.toIso8601String());
    });

    test('toJsonString produces valid JSON string', () {
      final createdAt = DateTime(2024, 1, 1, 12, 0);
      final response = CreateNetworkResponse(
        networkId: 'net-123',
        mainAgentId: 'agent-456',
        createdAt: createdAt,
      );

      final jsonString = response.toJsonString();
      final decoded = jsonDecode(jsonString);

      expect(decoded['networkId'], 'net-123');
      expect(decoded['mainAgentId'], 'agent-456');
    });
  });

  group('SendMessageRequest', () {
    test('fromJson parses valid JSON', () {
      final json = {'content': 'Test content'};

      final request = SendMessageRequest.fromJson(json);

      expect(request.content, 'Test content');
    });

    test('toJson produces valid JSON', () {
      final request = SendMessageRequest(content: 'Hello');

      final json = request.toJson();

      expect(json['content'], 'Hello');
    });
  });

  group('SSEEvent', () {
    test('toJson produces valid JSON with all fields', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0);
      final event = SSEEvent(
        agentId: 'agent-123',
        agentType: 'main',
        agentName: 'Main Agent',
        taskName: 'Task 1',
        type: 'message',
        data: {'content': 'test'},
        timestamp: timestamp,
      );

      final json = event.toJson();

      expect(json['agentId'], 'agent-123');
      expect(json['agentType'], 'main');
      expect(json['agentName'], 'Main Agent');
      expect(json['taskName'], 'Task 1');
      expect(json['type'], 'message');
      expect(json['data'], {'content': 'test'});
      expect(json['timestamp'], timestamp.toIso8601String());
    });

    test('toSSEFormat produces valid SSE format', () {
      final event = SSEEvent(
        agentId: 'agent-123',
        agentType: 'main',
        type: 'done',
      );

      final sseString = event.toSSEFormat();

      expect(sseString.startsWith('data: '), isTrue);
      expect(sseString.endsWith('\n\n'), isTrue);

      final jsonPart = sseString.substring(6, sseString.length - 2);
      final decoded = jsonDecode(jsonPart);
      expect(decoded['type'], 'done');
    });

    test('message factory creates correct event', () {
      final event = SSEEvent.message(
        agentId: 'agent-1',
        agentType: 'implementation',
        content: 'Hello',
        role: 'assistant',
      );

      expect(event.type, 'message');
      expect(event.data['role'], 'assistant');
      expect(event.data['content'], 'Hello');
    });

    test('toolUse factory creates correct event', () {
      final event = SSEEvent.toolUse(
        agentId: 'agent-1',
        agentType: 'main',
        toolName: 'Write',
        toolInput: {'file_path': 'test.dart'},
      );

      expect(event.type, 'tool_use');
      expect(event.data['toolName'], 'Write');
      expect(event.data['toolInput'], {'file_path': 'test.dart'});
    });

    test('toolResult factory creates correct event', () {
      final event = SSEEvent.toolResult(
        agentId: 'agent-1',
        agentType: 'main',
        toolName: 'Read',
        result: 'File contents',
        isError: false,
      );

      expect(event.type, 'tool_result');
      expect(event.data['toolName'], 'Read');
      expect(event.data['result'], 'File contents');
      expect(event.data['isError'], false);
    });

    test('done factory creates correct event', () {
      final event = SSEEvent.done(agentId: 'agent-1', agentType: 'main');

      expect(event.type, 'done');
      expect(event.data, isNull);
    });

    test('error factory creates correct event', () {
      final event = SSEEvent.error(
        agentId: 'agent-1',
        agentType: 'main',
        message: 'Something went wrong',
        stack: 'Stack trace here',
      );

      expect(event.type, 'error');
      expect(event.data['message'], 'Something went wrong');
      expect(event.data['stack'], 'Stack trace here');
    });

    test('status factory creates correct event', () {
      final event = SSEEvent.status(
        agentId: 'agent-1',
        agentType: 'main',
        status: 'working',
      );

      expect(event.type, 'status');
      expect(event.data['status'], 'working');
    });
  });
}
