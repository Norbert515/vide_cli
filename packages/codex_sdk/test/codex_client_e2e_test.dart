@Tags(['e2e'])
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

/// End-to-end test that runs a real `codex exec` process.
///
/// Requires:
///   - `codex` CLI installed and on PATH
///   - Valid OpenAI API key configured
///
/// Run with: dart test test/codex_client_e2e_test.dart --tags e2e
void main() {
  late CodexClient client;
  late Directory tempDir;

  setUpAll(() {
    final result = Process.runSync('which', ['codex']);
    if (result.exitCode != 0) {
      fail('codex CLI not found on PATH — skipping e2e tests');
    }
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('codex_e2e_');
    client = CodexClient(
      codexConfig: CodexConfig(
        workingDirectory: tempDir.path,
        skipGitRepoCheck: true,
      ),
    );
  });

  tearDown(() async {
    await client.close();
    // Small delay to let any dangling async handlers settle
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('sends a simple prompt and receives a complete conversation', () async {
    await client.init();

    // Subscribe to streams BEFORE sending the message to avoid races
    final turnFuture = client.onTurnComplete.first;
    final statuses = <ClaudeStatus>[];
    final sub = client.statusStream.listen(statuses.add);

    client.sendMessage(
      Message(text: 'Respond with exactly: "hello from codex"'),
    );

    await turnFuture.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('Timed out waiting for turn completion'),
    );
    await sub.cancel();

    final conv = client.currentConversation;
    expect(conv.messages, isNotEmpty);

    // First message should be the user message we sent
    final userMsg = conv.messages.first;
    expect(userMsg.role, MessageRole.user);
    expect(userMsg.content, contains('hello from codex'));

    // Should have at least one assistant message
    final assistantMessages = conv.messages
        .where((m) => m.role == MessageRole.assistant)
        .toList();
    expect(
      assistantMessages,
      isNotEmpty,
      reason: 'Expected assistant messages in conversation',
    );

    // The assistant message should have responses with text content
    final lastAssistant = assistantMessages.last;
    expect(
      lastAssistant.responses,
      isNotEmpty,
      reason:
          'No responses. Types: ${conv.messages.map((m) => '${m.role}: ${m.responses.map((r) => r.runtimeType).toList()}').toList()}',
    );

    final textResponses = lastAssistant.responses
        .whereType<TextResponse>()
        .toList();
    expect(
      textResponses,
      isNotEmpty,
      reason:
          'No TextResponse. Types: ${lastAssistant.responses.map((r) => '${r.runtimeType}(${r.id})').toList()}',
    );

    final allText = textResponses.map((r) => r.content).join();
    expect(allText, isNotEmpty);

    // Status should have gone through processing -> ready
    expect(statuses, contains(ClaudeStatus.processing));
    expect(statuses.last, ClaudeStatus.ready);
    expect(conv.isProcessing, isFalse);
  });

  test('captures thread ID from thread.started event', () async {
    await client.init();

    final turnFuture = client.onTurnComplete.first;
    client.sendMessage(Message(text: 'Say "ok"'));

    await turnFuture.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('Timed out waiting for turn completion'),
    );

    expect(
      client.initData,
      isNotNull,
      reason: 'Expected MetaResponse from thread.started',
    );
    expect(client.initData!.metadata['session_id'], isNotEmpty);
  });

  test('status transitions correctly during a turn', () async {
    await client.init();

    final statuses = <ClaudeStatus>[];
    final sub = client.statusStream.listen(statuses.add);
    final turnFuture = client.onTurnComplete.first;

    expect(client.currentStatus, ClaudeStatus.ready);

    client.sendMessage(Message(text: 'Say "test"'));

    // Should immediately transition to processing
    expect(client.currentStatus, ClaudeStatus.processing);

    await turnFuture.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('Timed out'),
    );
    await sub.cancel();

    expect(client.currentStatus, ClaudeStatus.ready);
    expect(statuses.first, ClaudeStatus.processing);
    expect(statuses.last, ClaudeStatus.ready);
  });

  test('abort kills the process and resets status', () async {
    await client.init();

    final processingFuture = client.statusStream
        .firstWhere((s) => s == ClaudeStatus.processing)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => ClaudeStatus.ready,
        );

    client.sendMessage(
      Message(
        text:
            'Write a very long essay about the complete history of computing '
            'from ancient abacuses to quantum computing. Include at least 100 '
            'detailed paragraphs covering every decade.',
      ),
    );

    final status = await processingFuture;
    if (status == ClaudeStatus.processing) {
      await client.abort();
      expect(client.currentStatus, ClaudeStatus.ready);
    }
    // If it already finished, that's fine
  });

  test('clearConversation resets state', () async {
    await client.init();

    final turnFuture = client.onTurnComplete.first;
    client.sendMessage(Message(text: 'Say "hello"'));

    await turnFuture.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('Timed out'),
    );

    expect(client.currentConversation.messages, isNotEmpty);

    await client.clearConversation();
    expect(client.currentConversation.messages, isEmpty);
  });

  test('multi-turn resume sends follow-up on same thread', () async {
    await client.init();

    // Turn 1: establish a fact
    final turn1Future = client.onTurnComplete.first;
    client.sendMessage(
      Message(text: 'Remember this number: 42. Just say "ok, remembered."'),
    );

    await turn1Future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('Timed out on turn 1'),
    );

    // Should have captured a thread ID
    expect(client.initData, isNotNull);
    final threadId = client.initData!.metadata['session_id'] as String;
    expect(threadId, isNotEmpty);

    // Turn 2: ask about the fact (resume on same thread)
    final turn2Future = client.onTurnComplete.first;
    client.sendMessage(
      Message(text: 'What number did I just tell you to remember? Reply with just the number.'),
    );

    await turn2Future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('Timed out on turn 2'),
    );

    // Should have user + assistant messages from both turns
    final conv = client.currentConversation;
    final userMessages = conv.messages
        .where((m) => m.role == MessageRole.user)
        .toList();
    expect(
      userMessages.length,
      greaterThanOrEqualTo(2),
      reason: 'Expected at least 2 user messages for multi-turn',
    );

    final assistantMessages = conv.messages
        .where((m) => m.role == MessageRole.assistant)
        .toList();
    expect(
      assistantMessages.length,
      greaterThanOrEqualTo(2),
      reason:
          'Expected at least 2 assistant messages for multi-turn. '
          'Messages: ${conv.messages.map((m) => '${m.role}(${m.responses.length} responses)').toList()}',
    );

    // The second assistant response should reference the number
    final lastAssistant = assistantMessages.last;
    final textResponses = lastAssistant.responses
        .whereType<TextResponse>()
        .toList();
    expect(
      textResponses,
      isNotEmpty,
      reason:
          'No TextResponse in last assistant. '
          'Response types: ${lastAssistant.responses.map((r) => '${r.runtimeType}(${r.id})').toList()}. '
          'All messages: ${conv.messages.map((m) => '${m.role}: ${m.responses.map((r) => '${r.runtimeType}').toList()}').toList()}',
    );

    final allText = textResponses.map((r) => r.content).join();
    expect(
      allText,
      contains('42'),
      reason: 'Expected assistant to recall the number 42',
    );
  });

  test('cleans up .codex/config.toml on close', () async {
    await client.init();

    final codexDir = Directory('${tempDir.path}/.codex');
    codexDir.createSync();
    File('${codexDir.path}/config.toml').writeAsStringSync('# test config\n');

    await client.close();

    expect(File('${codexDir.path}/config.toml').existsSync(), isFalse);
  });
}
