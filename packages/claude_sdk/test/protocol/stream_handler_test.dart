import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:claude_sdk/src/protocol/stream_handler.dart';
import '../helpers/fake_process.dart';

void main() {
  group('StreamHandler', () {
    late StreamHandler streamHandler;
    late FakeProcess fakeProcess;

    setUp(() {
      streamHandler = StreamHandler();
      fakeProcess = FakeProcess();
    });

    tearDown(() async {
      await streamHandler.dispose();
      await fakeProcess.dispose();
    });

    group('attachToProcess', () {
      test('emits TextResponse for valid text JSON', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout('{"type": "text", "content": "Hello"}');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<TextResponse>());
        expect((responses.first as TextResponse).content, equals('Hello'));
      });

      test('emits ToolUseResponse for tool_use JSON', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout(
          '{"type": "tool_use", "name": "Read", "input": {"file_path": "/test.txt"}}',
        );

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<ToolUseResponse>());
        final toolUse = responses.first as ToolUseResponse;
        expect(toolUse.toolName, equals('Read'));
        expect(toolUse.parameters['file_path'], equals('/test.txt'));
      });

      test('emits ErrorResponse for stderr output', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStderr('Command failed: invalid argument');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<ErrorResponse>());
        final error = responses.first as ErrorResponse;
        expect(error.error, equals('CLI Error'));
        expect(error.details, contains('Command failed'));
      });

      test('emits CompletionResponse when process ends', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.complete(0);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.any((r) => r is CompletionResponse), isTrue);
        final completion = responses.whereType<CompletionResponse>().first;
        expect(completion.stopReason, equals('process_ended'));
      });

      test('handles multiple responses in sequence', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdoutLines([
          '{"type": "text", "content": "First"}',
          '{"type": "text", "content": "Second"}',
          '{"type": "text", "content": "Third"}',
        ]);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(responses.length, greaterThanOrEqualTo(3));
        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.length, equals(3));
        expect(textResponses[0].content, equals('First'));
        expect(textResponses[1].content, equals('Second'));
        expect(textResponses[2].content, equals('Third'));
      });

      test('ignores empty lines', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdoutRaw(utf8.encode('\n\n'));
        fakeProcess.emitStdout('{"type": "text", "content": "Valid"}');
        fakeProcess.emitStdoutRaw(utf8.encode('   \n'));

        await Future.delayed(const Duration(milliseconds: 50));

        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.length, equals(1));
        expect(textResponses.first.content, equals('Valid'));
      });

      test('handles malformed JSON gracefully', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout('not valid json');
        fakeProcess.emitStdout('{"type": "text", "content": "Valid"}');

        await Future.delayed(const Duration(milliseconds: 50));

        // Should still get the valid response
        final textResponses = responses.whereType<TextResponse>().toList();
        expect(textResponses.length, equals(1));
        expect(textResponses.first.content, equals('Valid'));
      });

      test('emits ErrorResponse on stream error', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        // Simulate stream error by completing with error exit code
        fakeProcess.completeWithError(1, 'Process crashed');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.any((r) => r is ErrorResponse), isTrue);
      });
    });

    group('broadcast stream', () {
      test('allows multiple listeners', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses1 = <ClaudeResponse>[];
        final responses2 = <ClaudeResponse>[];

        streamHandler.responses.listen(responses1.add);
        streamHandler.responses.listen(responses2.add);

        fakeProcess.emitStdout('{"type": "text", "content": "Hello"}');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses1.length, equals(1));
        expect(responses2.length, equals(1));
      });
    });

    group('dispose', () {
      test('cancels subscriptions and closes controller', () async {
        streamHandler.attachToProcess(fakeProcess);

        var streamClosed = false;
        streamHandler.responses.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );

        await streamHandler.dispose();

        expect(streamClosed, isTrue);
      });
    });

    group('response type parsing', () {
      test('parses status response', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout(
          '{"type": "status", "status": "processing", "message": "Working..."}',
        );

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<StatusResponse>());
        final status = responses.first as StatusResponse;
        expect(status.status, equals(ClaudeStatus.processing));
        expect(status.message, equals('Working...'));
      });

      test('parses error response', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout(
          '{"type": "error", "error": "Rate limited", "details": "Too many requests"}',
        );

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<ErrorResponse>());
        final error = responses.first as ErrorResponse;
        expect(error.error, equals('Rate limited'));
        expect(error.details, equals('Too many requests'));
      });

      test('parses result/completion response', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout(
          '{"type": "result", "subtype": "success", "uuid": "test-123", "usage": {"input_tokens": 100, "output_tokens": 50}}',
        );

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<CompletionResponse>());
        final completion = responses.first as CompletionResponse;
        expect(completion.inputTokens, equals(100));
        expect(completion.outputTokens, equals(50));
      });

      test('parses assistant message with tool_use', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        final assistantMessage = jsonEncode({
          'type': 'assistant',
          'message': {
            'id': 'msg_123',
            'role': 'assistant',
            'content': [
              {
                'type': 'tool_use',
                'id': 'tool_456',
                'name': 'Bash',
                'input': {'command': 'ls -la'},
              },
            ],
          },
        });

        fakeProcess.emitStdout(assistantMessage);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<ToolUseResponse>());
        final toolUse = responses.first as ToolUseResponse;
        expect(toolUse.toolName, equals('Bash'));
        expect(toolUse.parameters['command'], equals('ls -la'));
      });

      test('parses unknown response type', () async {
        streamHandler.attachToProcess(fakeProcess);

        final responses = <ClaudeResponse>[];
        streamHandler.responses.listen(responses.add);

        fakeProcess.emitStdout('{"type": "future_type", "some_data": "value"}');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(responses.length, equals(1));
        expect(responses.first, isA<UnknownResponse>());
        expect(responses.first.rawData?['type'], equals('future_type'));
      });
    });
  });
}
