import 'dart:io';
import 'package:claude_sdk/claude_sdk.dart';

/// Create a TextResponse for testing
TextResponse createTextResponse(String content, {String? id}) {
  return TextResponse(
    id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: DateTime.now(),
    content: content,
  );
}

/// Create a ToolUseResponse for testing
ToolUseResponse createToolUseResponse(
  String toolName,
  Map<String, dynamic> params, {
  String? id,
  String? toolUseId,
}) {
  return ToolUseResponse(
    id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: DateTime.now(),
    toolName: toolName,
    parameters: params,
    toolUseId: toolUseId,
  );
}

/// Create a ToolResultResponse for testing
ToolResultResponse createToolResultResponse(
  String toolUseId,
  String content, {
  String? id,
  bool isError = false,
}) {
  return ToolResultResponse(
    id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: DateTime.now(),
    toolUseId: toolUseId,
    content: content,
    isError: isError,
  );
}

/// Create a CompletionResponse for testing
CompletionResponse createCompletionResponse({
  String? id,
  String stopReason = 'end_turn',
  int inputTokens = 100,
  int outputTokens = 50,
}) {
  return CompletionResponse(
    id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: DateTime.now(),
    stopReason: stopReason,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
  );
}

/// Create an ErrorResponse for testing
ErrorResponse createErrorResponse(
  String error, {
  String? id,
  String? details,
  String? code,
}) {
  return ErrorResponse(
    id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: DateTime.now(),
    error: error,
    details: details,
    code: code,
  );
}

/// Create a minimal Conversation for testing
Conversation createTestConversation({
  List<ConversationMessage>? messages,
  ConversationState state = ConversationState.idle,
  int totalInputTokens = 0,
  int totalOutputTokens = 0,
}) {
  return Conversation(
    messages: messages ?? [],
    state: state,
    totalInputTokens: totalInputTokens,
    totalOutputTokens: totalOutputTokens,
  );
}

/// Create a temp directory structure for conversation files
Future<Directory> createConversationTempDir(
  String sessionId,
  String projectPath,
  List<String> jsonlLines,
) async {
  final tempDir = await Directory.systemTemp.createTemp('claude_sdk_test_');

  // Create .claude/projects directory structure
  final claudeDir = Directory('${tempDir.path}/.claude/projects');
  await claudeDir.create(recursive: true);

  // Encode project path (replace / and _ with -)
  final encodedPath = projectPath
      .replaceAll('/', '-')
      .replaceAll('_', '-')
      .replaceAll(RegExp(r'^-+'), ''); // Remove leading dashes

  // Create conversation file
  final conversationFile = File(
    '${claudeDir.path}/$encodedPath/$sessionId.jsonl',
  );
  await conversationFile.parent.create(recursive: true);
  await conversationFile.writeAsString(jsonlLines.join('\n'));

  return tempDir;
}

/// Wait for stream to emit expected number of items
Future<List<T>> collectStream<T>(
  Stream<T> stream,
  int count, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final items = <T>[];
  await for (final item in stream.timeout(timeout)) {
    items.add(item);
    if (items.length >= count) break;
  }
  return items;
}
