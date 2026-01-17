/// Adapter to convert ToolContent from the public API to ToolInvocation for renderers.
///
/// This allows the TUI tool renderers to work with both the internal ToolInvocation type
/// and the public API ToolContent type during migration.
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

/// Extension on ToolContent to provide ToolInvocation-like API.
///
/// This allows code to use ToolContent with the same API as ToolInvocation
/// without needing to convert.
extension ToolContentHelpers on api.ToolContent {
  /// Whether the tool has completed (has a result).
  bool get hasResult => result != null;

  /// Whether the tool execution is complete.
  bool get isComplete => result != null;

  /// The result content as a string (null if not complete).
  String? get resultContent => result;

  /// The input parameters for the tool.
  Map<String, dynamic> get parameters => toolInput;

  /// Returns a user-friendly display name for the tool.
  String get displayName {
    if (!toolName.startsWith('mcp__')) {
      return toolName;
    }

    // Parse MCP tool name: mcp__server-name__toolName
    final parts = toolName.substring(5).split('__');
    if (parts.length != 2) {
      return toolName;
    }

    // Format server name: kebab-case to Title Case
    final serverName = parts[0]
        .split('-')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');

    return '$serverName: ${parts[1]}';
  }
}
