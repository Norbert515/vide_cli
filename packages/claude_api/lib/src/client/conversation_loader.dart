import 'dart:convert';
import 'dart:io';
import '../errors/claude_errors.dart';
import '../models/conversation.dart';
import '../models/response.dart';
import '../models/message.dart';
import '../utils/html_entity_decoder.dart';

/// Loads historical conversations from Claude Code's storage format.
///
/// Claude Code stores conversations in:
/// - ~/.claude/history.jsonl - metadata for all conversations
/// - ~/.claude/projects/{project-path}/{sessionId}.jsonl - full conversation data
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

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final type = json['type'] as String?;

        if (type == 'user') {
          lastAssistantMessageId = null; // Reset on user message
          final msg = _parseUserMessage(json);
          if (msg != null) {
            // Check if this is a tool result that should be added to the last assistant message
            if (msg.role == MessageRole.assistant &&
                msg.responses.isNotEmpty &&
                msg.responses.every((r) => r is ToolResultResponse)) {
              // This is a tool result - merge it into the last assistant message
              if (messages.isNotEmpty &&
                  messages.last.role == MessageRole.assistant) {
                final lastMsg = messages.last;
                final updatedResponses = [
                  ...lastMsg.responses,
                  ...msg.responses,
                ];
                messages[messages.length - 1] = lastMsg.copyWith(
                  responses: updatedResponses,
                );
              }
            } else {
              messages.add(msg);
            }
          }
        } else if (type == 'assistant') {
          final msg = _parseAssistantMessage(json);
          if (msg != null) {
            // Get the message ID from the assistant message
            final messageData = json['message'] as Map<String, dynamic>?;
            final currentMessageId = messageData?['id'] as String?;

            // Check if this is a continuation of the previous assistant message
            if (currentMessageId != null &&
                currentMessageId == lastAssistantMessageId &&
                messages.isNotEmpty &&
                messages.last.role == MessageRole.assistant) {
              // Merge responses into the last assistant message
              final lastMsg = messages.last;
              final updatedResponses = [...lastMsg.responses, ...msg.responses];
              messages[messages.length - 1] = lastMsg.copyWith(
                responses: updatedResponses,
              );
            } else {
              // New assistant message
              messages.add(msg);
              lastAssistantMessageId = currentMessageId;
            }
          }
        }
        // Ignore other types (summary, etc.) - they're not messages
      } catch (e) {
        // Continue parsing other lines
      }
    }

    return Conversation(messages: messages, state: ConversationState.idle);
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

  /// Parse user message from JSONL event
  static ConversationMessage? _parseUserMessage(Map<String, dynamic> json) {
    try {
      final messageData = json['message'] as Map<String, dynamic>?;
      if (messageData == null) return null;

      final content = messageData['content'];
      final timestampStr = json['timestamp'] as String?;
      final timestamp = timestampStr != null
          ? DateTime.tryParse(timestampStr)
          : null;

      // Content can be a string or array of content blocks
      String textContent = '';
      List<Attachment>? attachments;

      if (content is String) {
        textContent = HtmlEntityDecoder.decode(content);
      } else if (content is List) {
        // First check if this is a tool_result message
        final toolResults = <ToolResultResponse>[];

        for (final block in content) {
          if (block is Map<String, dynamic>) {
            final blockType = block['type'] as String?;
            if (blockType == 'tool_result') {
              // This is a tool result - extract the fields
              final toolUseId = block['tool_use_id'] as String? ?? '';
              final isError = block['is_error'] as bool? ?? false;

              // Handle both string and array content formats
              // Normal tools: "content": "string"
              // MCP tools: "content": [{"type": "text", "text": "string"}]
              String resultContent = '';
              final rawContent = block['content'];
              if (rawContent is String) {
                resultContent = rawContent;
              } else if (rawContent is List) {
                // Extract text from array of content blocks
                for (final item in rawContent) {
                  if (item is Map<String, dynamic> && item['type'] == 'text') {
                    resultContent += item['text'] as String? ?? '';
                  }
                }
              }

              toolResults.add(
                ToolResultResponse(
                  id:
                      json['uuid'] as String? ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  timestamp: timestamp ?? DateTime.now(),
                  toolUseId: toolUseId,
                  content: HtmlEntityDecoder.decode(resultContent),
                  isError: isError,
                ),
              );
            }
          }
        }

        // If we found tool results, return them as an assistant message
        // (tool results are displayed as part of assistant's tool execution flow)
        if (toolResults.isNotEmpty) {
          return ConversationMessage.assistant(
            id:
                timestamp?.millisecondsSinceEpoch.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            responses: toolResults,
            isComplete: true,
          );
        }

        // Otherwise parse as regular user message with text/images
        final textParts = <String>[];
        final imageAttachments = <Attachment>[];

        for (final block in content) {
          if (block is Map<String, dynamic>) {
            final blockType = block['type'] as String?;
            if (blockType == 'text') {
              textParts.add(block['text'] as String? ?? '');
            } else if (blockType == 'image') {
              // Images stored as base64 in source.data
              final source = block['source'] as Map<String, dynamic>?;
              if (source != null && source['type'] == 'base64') {
                // For display purposes, we just note that an image was attached
                imageAttachments.add(Attachment.image('[embedded image]'));
              }
            }
          }
        }

        textContent = HtmlEntityDecoder.decode(textParts.join('\n'));
        if (imageAttachments.isNotEmpty) {
          attachments = imageAttachments;
        }
      }

      return ConversationMessage(
        id:
            timestamp?.millisecondsSinceEpoch.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.user,
        content: textContent,
        timestamp: timestamp ?? DateTime.now(),
        isComplete: true,
        attachments: attachments,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse assistant message from JSONL event
  static ConversationMessage? _parseAssistantMessage(
    Map<String, dynamic> json,
  ) {
    try {
      final messageData = json['message'] as Map<String, dynamic>?;
      if (messageData == null) return null;

      final content = messageData['content'];
      final timestampStr = json['timestamp'] as String?;
      final timestamp = timestampStr != null
          ? DateTime.tryParse(timestampStr)
          : null;
      final responses = <ClaudeResponse>[];

      if (content is List) {
        for (final block in content) {
          if (block is Map<String, dynamic>) {
            final blockType = block['type'] as String?;

            if (blockType == 'text') {
              final text = block['text'] as String? ?? '';
              if (text.isNotEmpty) {
                responses.add(
                  TextResponse(
                    id:
                        block['id'] as String? ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    timestamp: DateTime.now(),
                    content: HtmlEntityDecoder.decode(text),
                  ),
                );
              }
            } else if (blockType == 'tool_use') {
              final toolName = block['name'] as String? ?? 'unknown';
              final parameters = block['input'] as Map<String, dynamic>? ?? {};
              responses.add(
                ToolUseResponse(
                  id:
                      block['id'] as String? ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  timestamp: DateTime.now(),
                  toolName: HtmlEntityDecoder.decode(toolName),
                  parameters: HtmlEntityDecoder.decodeMap(parameters),
                  toolUseId: block['id'] as String?,
                ),
              );
            }
          }
        }
      }

      // If no content blocks, just create empty response
      if (responses.isEmpty) {
        return null; // Skip empty assistant messages
      }

      return ConversationMessage.assistant(
        id:
            timestamp?.millisecondsSinceEpoch.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        responses: responses,
        isComplete: true,
      );
    } catch (e) {
      return null;
    }
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
