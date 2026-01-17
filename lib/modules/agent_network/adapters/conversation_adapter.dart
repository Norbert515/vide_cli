/// Adapters to bridge vide_core public API types to claude_sdk types.
///
/// This allows the TUI to gradually migrate from internal claude_sdk types
/// to the public vide_core API while reusing existing renderers.
library;

import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/api.dart' as api;

/// Converts a [api.ToolContent] to a [ToolInvocation] for use with existing renderers.
ToolInvocation toolContentToInvocation(api.ToolContent content) {
  final now = DateTime.now();

  // Create a ToolUseResponse from the tool content
  final toolCall = ToolUseResponse(
    id: content.toolUseId,
    timestamp: now,
    toolName: content.toolName,
    parameters: content.toolInput,
    toolUseId: content.toolUseId,
  );

  // Create a ToolResultResponse if we have a result
  final ToolResultResponse? toolResult;
  if (content.result != null) {
    toolResult = ToolResultResponse(
      id: '${content.toolUseId}-result',
      timestamp: now,
      toolUseId: content.toolUseId,
      content: content.result!,
      isError: content.isError,
    );
  } else {
    toolResult = null;
  }

  return ToolInvocation(
    toolCall: toolCall,
    toolResult: toolResult,
  );
}

/// Converts a [api.VideMessage] to components that can be rendered.
///
/// Returns a list of content blocks that can be processed by the message renderer.
/// Text content is concatenated, tool content is converted to ToolInvocation.
class VideMessageAdapter {
  final api.VideMessage message;

  VideMessageAdapter(this.message);

  /// Get the role of this message.
  String get role => message.role;

  /// Whether this message is still streaming.
  bool get isStreaming => message.isStreaming;

  /// Get the full text content (concatenated from all TextContent blocks).
  String get textContent => message.text;

  /// Get all tool invocations in this message.
  List<ToolInvocation> get toolInvocations {
    final tools = <ToolInvocation>[];
    for (final content in message.content) {
      if (content is api.ToolContent) {
        tools.add(toolContentToInvocation(content));
      }
    }
    return tools;
  }

  /// Iterate through content in order, yielding either text segments or tool invocations.
  ///
  /// This preserves the interleaving order of text and tools for correct rendering.
  Iterable<MessageContentBlock> get contentBlocks sync* {
    final textBuffer = StringBuffer();
    bool textIsStreaming = false;

    for (final content in message.content) {
      if (content is api.TextContent) {
        // Accumulate text
        textBuffer.write(content.text);
        textIsStreaming = content.isStreaming;
      } else if (content is api.ToolContent) {
        // Flush any accumulated text before the tool
        if (textBuffer.isNotEmpty) {
          yield TextContentBlock(
            text: textBuffer.toString(),
            isStreaming: false, // Text before a tool is complete
          );
          textBuffer.clear();
        }
        // Yield the tool
        yield ToolContentBlock(
          invocation: toolContentToInvocation(content),
        );
      }
    }

    // Flush any remaining text
    if (textBuffer.isNotEmpty) {
      yield TextContentBlock(
        text: textBuffer.toString(),
        isStreaming: textIsStreaming,
      );
    }
  }
}

/// A block of content within a message.
sealed class MessageContentBlock {}

/// Text content block.
class TextContentBlock extends MessageContentBlock {
  final String text;
  final bool isStreaming;

  TextContentBlock({required this.text, required this.isStreaming});
}

/// Tool invocation content block.
class ToolContentBlock extends MessageContentBlock {
  final ToolInvocation invocation;

  ToolContentBlock({required this.invocation});
}
