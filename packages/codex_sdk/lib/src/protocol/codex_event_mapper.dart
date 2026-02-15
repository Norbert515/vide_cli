import 'package:claude_sdk/claude_sdk.dart';

import 'codex_event.dart';

/// Maps [CodexEvent]s to [ClaudeResponse] objects.
///
/// This allows the entire downstream pipeline (ResponseProcessor,
/// Conversation, TUI, vide_server) to work unchanged — they all
/// consume ClaudeResponse types regardless of which backend produced them.
class CodexEventMapper {
  int _idCounter = 0;

  String _nextId() => 'codex_${_idCounter++}';

  /// Map a single Codex event to zero or more ClaudeResponse objects.
  List<ClaudeResponse> mapEvent(CodexEvent event) {
    return switch (event) {
      // Thread lifecycle
      ThreadStartedEvent e => _mapThreadStarted(e),
      ThreadNameUpdatedEvent _ => [],
      ThreadCompactedEvent _ => [],

      // Turn lifecycle
      TurnStartedEvent _ => _mapTurnStarted(),
      TurnCompletedEvent _ => _mapTurnCompleted(),

      // Item lifecycle
      ItemStartedEvent e => _mapItemStarted(e),
      ItemCompletedEvent e => _mapItemCompleted(e),

      // Streaming deltas
      AgentMessageDeltaEvent e => _mapAgentMessageDelta(e),
      ReasoningSummaryDeltaEvent _ => [],
      ReasoningTextDeltaEvent _ => [],
      CommandOutputDeltaEvent _ => [],
      FileChangeOutputDeltaEvent _ => [],
      McpToolCallProgressEvent _ => [],

      // Token usage
      TokenUsageUpdatedEvent e => _mapTokenUsage(e),

      // Legacy events
      TaskCompleteEvent e => _mapTaskComplete(e),
      McpStartupCompleteEvent _ => [],

      // Errors
      CodexErrorEvent e => _mapError(e),

      // Unknown
      UnknownCodexEvent _ => [],
    };
  }

  // --------------------------------------------------------------------------
  // Thread lifecycle
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapThreadStarted(ThreadStartedEvent event) {
    return [
      MetaResponse(
        id: event.threadId,
        timestamp: DateTime.now(),
        metadata: {'session_id': event.threadId},
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Turn lifecycle
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapTurnStarted() {
    return [
      StatusResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        status: ClaudeStatus.processing,
      ),
    ];
  }

  List<ClaudeResponse> _mapTurnCompleted() {
    return [
      CompletionResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        stopReason: 'completed',
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Item lifecycle
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapItemStarted(ItemStartedEvent event) {
    return switch (event.itemType) {
      'agentMessage' => [],
      'commandExecution' => _mapCommandExecutionStarted(event),
      'fileChange' => _mapFileChangeStarted(event),
      'mcpToolCall' => _mapMcpToolCallStarted(event),
      'reasoning' => [],
      'webSearch' => _mapWebSearchStarted(event),
      'todoList' => [],
      _ => [],
    };
  }

  List<ClaudeResponse> _mapItemCompleted(ItemCompletedEvent event) {
    return switch (event.itemType) {
      'agentMessage' => _mapAgentMessageCompleted(event),
      'commandExecution' => _mapCommandExecutionCompleted(event),
      'fileChange' => _mapFileChangeCompleted(event),
      'mcpToolCall' => _mapMcpToolCallCompleted(event),
      'reasoning' => _mapReasoningCompleted(event),
      'webSearch' => _mapWebSearchCompleted(event),
      'todoList' => _mapTodoListCompleted(event),
      _ => [],
    };
  }

  // --------------------------------------------------------------------------
  // Streaming deltas
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapAgentMessageDelta(AgentMessageDeltaEvent event) {
    return [
      TextResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        content: event.delta,
        isCumulative: false,
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Token usage
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapTokenUsage(TokenUsageUpdatedEvent event) {
    return [
      CompletionResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        stopReason: 'usage_update',
        inputTokens: event.usage.inputTokens,
        outputTokens: event.usage.outputTokens,
        cacheReadInputTokens: event.usage.cachedInputTokens,
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Legacy events
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapTaskComplete(TaskCompleteEvent event) {
    return [
      CompletionResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        stopReason: 'completed',
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Errors
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapError(CodexErrorEvent event) {
    return [
      ErrorResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        error: event.message,
        details: event.details?.toString(),
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Item type handlers
  // --------------------------------------------------------------------------

  List<ClaudeResponse> _mapAgentMessageCompleted(ItemCompletedEvent event) {
    final text = _extractStringField(event.itemData, 'text') ?? '';
    if (text.isEmpty) return [];
    return [
      TextResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        content: text,
        isCumulative: true,
      ),
    ];
  }

  List<ClaudeResponse> _mapCommandExecutionStarted(ItemStartedEvent event) {
    return [
      ToolUseResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        toolName: 'Bash',
        parameters: {'command': event.itemData['command'] as String? ?? ''},
        toolUseId: event.itemId,
      ),
    ];
  }

  List<ClaudeResponse> _mapCommandExecutionCompleted(
    ItemCompletedEvent event,
  ) {
    final exitCode = event.itemData['exit_code'] as int?;
    final output =
        event.itemData['aggregated_output'] as String? ??
        event.itemData['output'] as String? ??
        '';
    return [
      ToolResultResponse(
        id: '${event.itemId}_result',
        timestamp: DateTime.now(),
        toolUseId: event.itemId,
        content: output,
        isError: exitCode != null && exitCode != 0,
      ),
    ];
  }

  List<ClaudeResponse> _mapFileChangeStarted(ItemStartedEvent event) {
    final changes = event.itemData['changes'] as List<dynamic>?;
    final params = <String, dynamic>{};
    if (changes != null && changes.isNotEmpty) {
      final paths =
          changes.map((c) => (c as Map)['path'] as String? ?? '').toList();
      params['files'] = paths;
      final kind = (changes.first as Map)['kind'] as String? ?? 'update';
      params['kind'] = kind;
    }
    final toolName = _inferFileToolName(changes);
    return [
      ToolUseResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        toolName: toolName,
        parameters: params,
        toolUseId: event.itemId,
      ),
    ];
  }

  List<ClaudeResponse> _mapFileChangeCompleted(ItemCompletedEvent event) {
    final changes = event.itemData['changes'] as List<dynamic>?;
    final summary = changes != null
        ? changes
              .map((c) {
                final path = (c as Map)['path'] ?? '';
                final kind = c['kind'] ?? '';
                return '$kind: $path';
              })
              .join('\n')
        : 'Done';
    return [
      ToolResultResponse(
        id: '${event.itemId}_result',
        timestamp: DateTime.now(),
        toolUseId: event.itemId,
        content: summary,
        isError: false,
      ),
    ];
  }

  List<ClaudeResponse> _mapMcpToolCallStarted(ItemStartedEvent event) {
    final serverLabel = event.itemData['server'] as String? ?? '';
    final toolName = event.itemData['tool'] as String? ?? '';
    final fullName =
        serverLabel.isNotEmpty ? 'mcp__${serverLabel}__$toolName' : toolName;
    final arguments = event.itemData['arguments'];
    return [
      ToolUseResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        toolName: fullName,
        parameters:
            arguments is Map<String, dynamic>
                ? arguments
                : <String, dynamic>{},
        toolUseId: event.itemId,
      ),
    ];
  }

  List<ClaudeResponse> _mapMcpToolCallCompleted(ItemCompletedEvent event) {
    final error = event.itemData['error'];
    final isError = error != null;
    final content = isError
        ? _extractErrorMessage(error)
        : _extractMcpResult(event.itemData['result']);
    return [
      ToolResultResponse(
        id: '${event.itemId}_result',
        timestamp: DateTime.now(),
        toolUseId: event.itemId,
        content: content,
        isError: isError,
      ),
    ];
  }

  List<ClaudeResponse> _mapReasoningCompleted(ItemCompletedEvent event) {
    final text = _extractStringField(event.itemData, 'text') ??
        _extractStringField(event.itemData, 'summary') ??
        '';
    if (text.isEmpty) return [];
    return [
      TextResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        content: text,
        isCumulative: true,
      ),
    ];
  }

  List<ClaudeResponse> _mapWebSearchStarted(ItemStartedEvent event) {
    final query = event.itemData['query'] as String? ?? '';
    return [
      ToolUseResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        toolName: 'WebSearch',
        parameters: {'query': query},
        toolUseId: event.itemId,
      ),
    ];
  }

  List<ClaudeResponse> _mapWebSearchCompleted(ItemCompletedEvent event) {
    return [
      ToolResultResponse(
        id: '${event.itemId}_result',
        timestamp: DateTime.now(),
        toolUseId: event.itemId,
        content: 'Search complete',
        isError: false,
      ),
    ];
  }

  List<ClaudeResponse> _mapTodoListCompleted(ItemCompletedEvent event) {
    final items = event.itemData['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return [];
    final text = items
        .map((item) {
          final map = item as Map;
          final completed = map['completed'] as bool? ?? false;
          final label = map['text'] as String? ?? '';
          return '${completed ? '[x]' : '[ ]'} $label';
        })
        .join('\n');
    return [
      TextResponse(
        id: event.itemId,
        timestamp: DateTime.now(),
        content: text,
        isCumulative: true,
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  String _inferFileToolName(List<dynamic>? changes) {
    if (changes == null || changes.isEmpty) return 'Write';
    final kind = (changes.first as Map)['kind'] as String? ?? '';
    return switch (kind) {
      'add' => 'Write',
      'delete' => 'Write',
      'update' => 'Edit',
      _ => 'Write',
    };
  }

  String _extractMcpResult(dynamic result) {
    if (result == null) return '';
    if (result is String) return result;
    if (result is List) {
      return result
          .map((block) {
            if (block is Map && block['type'] == 'text') {
              return block['text'] as String? ?? '';
            }
            if (block is Map) return block.toString();
            return block.toString();
          })
          .join('\n');
    }
    if (result is Map) return result.toString();
    return result.toString();
  }

  String _extractErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Map) return error['message'] as String? ?? error.toString();
    return error.toString();
  }

  /// Extracts a string from a field that may be a String or a List of content
  /// blocks (e.g., `[{"type": "summary_text", "text": "..."}]`).
  String? _extractStringField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    if (value is List) {
      final parts = value
          .map((block) {
            if (block is Map && block.containsKey('text')) {
              return block['text'] as String? ?? '';
            }
            if (block is String) return block;
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join('\n');
    }
    return null;
  }
}
