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
      ThreadStartedEvent e => _mapThreadStarted(e),
      TurnStartedEvent _ => _mapTurnStarted(),
      TurnCompletedEvent e => _mapTurnCompleted(e),
      TurnFailedEvent e => _mapTurnFailed(e),
      ItemEvent e => _mapItem(e),
      CodexErrorEvent e => _mapError(e),
      UnknownCodexEvent _ => [],
    };
  }

  List<ClaudeResponse> _mapThreadStarted(ThreadStartedEvent event) {
    return [
      MetaResponse(
        id: event.threadId,
        timestamp: DateTime.now(),
        metadata: {'session_id': event.threadId},
      ),
    ];
  }

  List<ClaudeResponse> _mapTurnStarted() {
    return [
      StatusResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        status: ClaudeStatus.processing,
      ),
    ];
  }

  List<ClaudeResponse> _mapTurnCompleted(TurnCompletedEvent event) {
    return [
      CompletionResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        stopReason: 'completed',
        inputTokens: event.usage?.inputTokens,
        outputTokens: event.usage?.outputTokens,
        cacheReadInputTokens: event.usage?.cachedInputTokens,
      ),
    ];
  }

  List<ClaudeResponse> _mapTurnFailed(TurnFailedEvent event) {
    return [
      ErrorResponse(
        id: _nextId(),
        timestamp: DateTime.now(),
        error: event.error ?? 'Turn failed',
        details: event.details?.toString(),
      ),
    ];
  }

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

  List<ClaudeResponse> _mapItem(ItemEvent event) {
    return switch (event.itemType) {
      'agent_message' => _mapAgentMessage(event),
      'command_execution' => _mapCommandExecution(event),
      'file_change' => _mapFileChange(event),
      'mcp_tool_call' => _mapMcpToolCall(event),
      'reasoning' => _mapReasoning(event),
      'web_search' => _mapWebSearch(event),
      'todo_list' => _mapTodoList(event),
      _ => [],
    };
  }

  List<ClaudeResponse> _mapAgentMessage(ItemEvent event) {
    if (!event.isCompleted) return [];
    final text = event.data['text'] as String? ?? '';
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

  List<ClaudeResponse> _mapCommandExecution(ItemEvent event) {
    if (event.isStarted) {
      return [
        ToolUseResponse(
          id: event.itemId,
          timestamp: DateTime.now(),
          toolName: 'Bash',
          parameters: {'command': event.data['command'] as String? ?? ''},
          toolUseId: event.itemId,
        ),
      ];
    }
    if (event.isCompleted) {
      final exitCode = event.data['exit_code'] as int?;
      final output = event.data['aggregated_output'] as String? ?? '';
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
    return [];
  }

  List<ClaudeResponse> _mapFileChange(ItemEvent event) {
    // Codex emits file changes with a `changes` array:
    //   { "changes": [{ "path": "lib/foo.dart", "kind": "add" }, ...] }
    // where kind is "add", "update", or "delete".
    final changes = event.data['changes'] as List<dynamic>?;

    if (event.isStarted) {
      final params = <String, dynamic>{};
      if (changes != null && changes.isNotEmpty) {
        final paths = changes
            .map((c) => (c as Map)['path'] as String? ?? '')
            .toList();
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
    if (event.isCompleted) {
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
    return [];
  }

  List<ClaudeResponse> _mapMcpToolCall(ItemEvent event) {
    if (event.isStarted) {
      final serverLabel = event.data['server'] as String? ?? '';
      final toolName = event.data['tool'] as String? ?? '';
      final fullName = serverLabel.isNotEmpty
          ? 'mcp__${serverLabel}__$toolName'
          : toolName;
      final arguments = event.data['arguments'];
      return [
        ToolUseResponse(
          id: event.itemId,
          timestamp: DateTime.now(),
          toolName: fullName,
          parameters: arguments is Map<String, dynamic>
              ? arguments
              : <String, dynamic>{},
          toolUseId: event.itemId,
        ),
      ];
    }
    if (event.isCompleted) {
      final error = event.data['error'];
      final isError = error != null;
      final content = isError
          ? _extractErrorMessage(error)
          : _extractMcpResult(event.data['result']);
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
    return [];
  }

  List<ClaudeResponse> _mapReasoning(ItemEvent event) {
    if (!event.isCompleted) return [];
    final text =
        event.data['text'] as String? ?? event.data['summary'] as String? ?? '';
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

  List<ClaudeResponse> _mapWebSearch(ItemEvent event) {
    if (event.isStarted) {
      final query = event.data['query'] as String? ?? '';
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
    if (event.isCompleted) {
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
    return [];
  }

  List<ClaudeResponse> _mapTodoList(ItemEvent event) {
    if (!event.isCompleted && !event.isUpdated) return [];
    final items = event.data['items'] as List<dynamic>? ?? [];
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

  /// Extract text from MCP result, which can be a string, a content block
  /// array, or a plain map.
  String _extractMcpResult(dynamic result) {
    if (result == null) return '';
    if (result is String) return result;
    if (result is List) {
      // Content block array: [{type: "text", text: "..."}, ...]
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

  /// Extract error message from structured or string error.
  String _extractErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Map) return error['message'] as String? ?? error.toString();
    return error.toString();
  }
}
