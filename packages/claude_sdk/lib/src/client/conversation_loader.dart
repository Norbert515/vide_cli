import 'dart:convert';
import 'dart:io';
import '../errors/claude_errors.dart';
import '../models/conversation.dart';
import '../models/response.dart';
import 'response_to_message_converter.dart';

/// Loads historical conversations from Claude Code's storage format.
///
/// Claude Code stores conversations in:
/// - ~/.claude/history.jsonl - metadata for all conversations
/// - ~/.claude/projects/{project-path}/{sessionId}.jsonl - full conversation data
///
/// This loader uses the unified ClaudeResponse parsing pipeline to ensure
/// consistent behavior between loading from storage and live streaming.
class ConversationLoader {
  /// Loads a conversation's messages from disk for display in UI.
  ///
  /// This is read-only - the conversation is loaded for viewing past messages only.
  /// When the user sends a new message, it starts a fresh Claude Code session.
  ///
  /// [sessionId] - The Claude session ID (UUID)
  /// [projectPath] - The project path (e.g., "/Users/name/project")
  ///
  /// Returns a [Conversation] object with all past messages loaded.
  static Future<Conversation> loadHistoryForDisplay(
    String sessionId,
    String projectPath,
  ) async {
    // Encode project path for Claude Code's filesystem naming
    final encodedPath = _encodeProjectPath(projectPath);

    // Find conversation file: ~/.claude/projects/{encoded-path}/{sessionId}.jsonl
    final claudeDir = _getClaudeDirectory();
    final conversationFile = File(
      '$claudeDir/projects/$encodedPath/$sessionId.jsonl',
    );

    if (!await conversationFile.exists()) {
      throw ConversationLoadException(
        'Conversation file not found: ${conversationFile.path}',
        sessionId: sessionId,
      );
    }

    // Parse JSONL file line by line
    final lines = await conversationFile.readAsLines();
    final messages = <ConversationMessage>[];
    String? lastAssistantMessageId;

    // Track the latest usage data for context window display
    int lastInputTokens = 0;
    int lastCacheReadTokens = 0;
    int lastCacheCreationTokens = 0;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;

        // Skip meta messages early
        final isMeta = json['isMeta'] as bool? ?? false;
        if (isMeta) continue;

        // Use unified parsing pipeline
        final responses = JsonlMessageParser.parseLineMultiple(json);
        if (responses.isEmpty) continue;

        // Extract usage data for context window tracking
        final usage = JsonlMessageParser.extractUsage(json);
        if (usage != null) {
          lastInputTokens = usage.inputTokens;
          lastCacheReadTokens = usage.cacheReadTokens;
          lastCacheCreationTokens = usage.cacheCreationTokens;
        }

        // Extract message ID for assistant message merging
        final currentMessageId = JsonlMessageParser.extractMessageId(json);

        // Process each response
        for (final response in responses) {
          final message = ResponseToMessageConverter.convert(response);

          // Skip transient/ephemeral message types when loading history
          // These are only relevant during live streaming
          if (message.messageType == MessageType.status ||
              message.messageType == MessageType.meta ||
              message.messageType == MessageType.completion ||
              message.messageType == MessageType.unknown) {
            continue;
          }

          // Handle tool results - merge into last assistant message
          if (ResponseToMessageConverter.isToolResult(response)) {
            if (messages.isNotEmpty &&
                messages.last.role == MessageRole.assistant) {
              final lastMsg = messages.last;
              final updatedResponses = [
                ...lastMsg.responses,
                ...message.responses,
              ];
              messages[messages.length - 1] = lastMsg.copyWith(
                responses: updatedResponses,
              );
            }
            continue;
          }

          // Handle assistant messages - may need to merge
          if (message.role == MessageRole.assistant) {
            // Check if this is a continuation of the previous assistant message
            if (currentMessageId != null &&
                currentMessageId == lastAssistantMessageId &&
                messages.isNotEmpty &&
                messages.last.role == MessageRole.assistant) {
              // Merge responses into the last assistant message
              final lastMsg = messages.last;
              final updatedResponses = [
                ...lastMsg.responses,
                ...message.responses,
              ];
              messages[messages.length - 1] = lastMsg.copyWith(
                responses: updatedResponses,
              );
            } else {
              // New assistant message
              messages.add(
                message.copyWith(isComplete: true, isStreaming: false),
              );
              lastAssistantMessageId = currentMessageId;
            }
            continue;
          }

          // Handle user messages - reset assistant message tracking
          if (message.role == MessageRole.user) {
            lastAssistantMessageId = null;
            messages.add(message);
            continue;
          }

          // Other messages (compact boundary, etc.)
          messages.add(message);
          if (response is CompactBoundaryResponse) {
            lastAssistantMessageId = null;
          }
        }
      } catch (e) {
        // Continue parsing other lines on error
        continue;
      }
    }

    return Conversation(
      messages: messages,
      state: ConversationState.idle,
      // Set current context from the last assistant message's usage data
      currentContextInputTokens: lastInputTokens,
      currentContextCacheReadTokens: lastCacheReadTokens,
      currentContextCacheCreationTokens: lastCacheCreationTokens,
    );
  }

  /// Checks if a conversation file exists for the given session ID and project path.
  ///
  /// [sessionId] - The Claude session ID (UUID)
  /// [projectPath] - The project path (e.g., "/Users/name/project")
  ///
  /// Returns `true` if the conversation file exists, `false` otherwise.
  static Future<bool> hasConversation(
    String sessionId,
    String projectPath,
  ) async {
    final encodedPath = _encodeProjectPath(projectPath);
    final claudeDir = _getClaudeDirectory();
    final conversationFile = File(
      '$claudeDir/projects/$encodedPath/$sessionId.jsonl',
    );
    return conversationFile.exists();
  }

  /// Encode project path to match Claude Code's naming scheme
  /// Example: "/Users/foo/bar" -> "-Users-foo-bar"
  /// Example: "/Users/foo/bar_baz" -> "-Users-foo-bar-baz"
  static String _encodeProjectPath(String path) {
    return path.replaceAll('/', '-').replaceAll('_', '-');
  }

  /// Get Claude Code's storage directory (~/.claude)
  static String _getClaudeDirectory() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw ConversationLoadException(
        'Could not determine home directory: HOME and USERPROFILE environment variables are not set',
      );
    }
    return '$home/.claude';
  }
}
