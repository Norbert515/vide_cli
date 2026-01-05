import 'package:claude_sdk/claude_sdk.dart';

/// A raw event from a Claude Code conversation JSONL file.
///
/// This wraps both the raw JSON and the parsed ClaudeResponse,
/// allowing inspection of all event data without filtering.
class RawEvent {
  final int lineNumber;
  final Map<String, dynamic> rawJson;
  final ClaudeResponse? parsedResponse;
  final String? parseError;

  const RawEvent({
    required this.lineNumber,
    required this.rawJson,
    this.parsedResponse,
    this.parseError,
  });

  /// The raw "type" field from the JSON.
  String get rawType => rawJson['type'] as String? ?? 'unknown';

  /// The raw "subtype" field from the JSON.
  String get rawSubtype => rawJson['subtype'] as String? ?? '';

  /// The UUID of this event.
  String get uuid =>
      rawJson['uuid'] as String? ?? rawJson['id'] as String? ?? '';

  /// Whether this is a meta message.
  bool get isMeta => rawJson['isMeta'] as bool? ?? false;

  /// Whether this is a sidechain message.
  bool get isSidechain => rawJson['isSidechain'] as bool? ?? false;

  /// The timestamp of this event.
  DateTime? get timestamp {
    final ts = rawJson['timestamp'];
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  /// The session ID this event belongs to.
  String? get sessionId => rawJson['sessionId'] as String?;

  /// The working directory when this event occurred.
  String? get cwd => rawJson['cwd'] as String?;

  /// The git branch when this event occurred.
  String? get gitBranch => rawJson['gitBranch'] as String?;

  /// The name of the parsed response type.
  String get parsedTypeName {
    if (parsedResponse == null) {
      return parseError != null ? 'ParseError' : 'Unparsed';
    }
    return parsedResponse.runtimeType.toString();
  }

  /// Whether parsing succeeded.
  bool get isParsed => parsedResponse != null;

  /// Whether this event failed to parse.
  bool get hasParseError => parseError != null;

  /// Get a preview of the content for display.
  String getContentPreview({int maxLength = 100}) {
    String content = '';

    if (parsedResponse != null) {
      content = switch (parsedResponse!) {
        TextResponse r => r.content,
        ToolUseResponse r => 'Tool: ${r.toolName}',
        ToolResultResponse r => r.content,
        UserMessageResponse r => r.content,
        ErrorResponse r => 'Error: ${r.error}',
        StatusResponse r => 'Status: ${r.status.name}',
        MetaResponse r => 'Meta: ${r.conversationId ?? "init"}',
        CompletionResponse r =>
          'Completion: ${r.stopReason ?? "done"} (${r.outputTokens ?? 0} tokens)',
        CompactBoundaryResponse r => 'Compact: ${r.trigger} (${r.preTokens} tokens)',
        CompactSummaryResponse r => r.content,
        UnknownResponse _ => 'Unknown event',
      };
    } else {
      // Try to extract content from raw JSON
      final message = rawJson['message'];
      if (message is Map<String, dynamic>) {
        final messageContent = message['content'];
        if (messageContent is String) {
          content = messageContent;
        } else if (messageContent is List && messageContent.isNotEmpty) {
          final first = messageContent.first;
          if (first is Map<String, dynamic>) {
            content = first['text'] as String? ?? first['name'] as String? ?? '';
          }
        }
      }
      if (content.isEmpty) {
        content = rawType;
        if (rawSubtype.isNotEmpty) {
          content += ':$rawSubtype';
        }
      }
    }

    if (content.length > maxLength) {
      return '${content.substring(0, maxLength)}...';
    }
    return content;
  }

  /// Get the role (user/assistant/system) if applicable.
  String? get role {
    final message = rawJson['message'];
    if (message is Map<String, dynamic>) {
      return message['role'] as String?;
    }
    return rawType == 'user'
        ? 'user'
        : rawType == 'assistant'
            ? 'assistant'
            : rawType == 'system'
                ? 'system'
                : null;
  }

  @override
  String toString() => 'RawEvent(line: $lineNumber, type: $rawType, parsed: $parsedTypeName)';
}
