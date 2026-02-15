import 'json_rpc_message.dart';

/// Codex app-server event types.
///
/// These represent the JSON-RPC notifications sent by `codex app-server`.
/// Each event corresponds to a notification method (e.g. `item/started`,
/// `item/agentMessage/delta`).
sealed class CodexEvent {
  const CodexEvent();

  /// Parse a [JsonRpcNotification] into a typed [CodexEvent].
  factory CodexEvent.fromNotification(JsonRpcNotification notification) {
    final method = notification.method;
    final params = notification.params;

    return switch (method) {
      // Thread lifecycle
      'thread/started' => ThreadStartedEvent.fromParams(params),
      'thread/name/updated' => ThreadNameUpdatedEvent.fromParams(params),
      'thread/tokenUsage/updated' =>
        TokenUsageUpdatedEvent.fromParams(params),
      'thread/compacted' => ThreadCompactedEvent.fromParams(params),

      // Turn lifecycle
      'turn/started' => TurnStartedEvent.fromParams(params),
      'turn/completed' => TurnCompletedEvent.fromParams(params),

      // Item lifecycle
      'item/started' => ItemStartedEvent.fromParams(params),
      'item/completed' => ItemCompletedEvent.fromParams(params),

      // Streaming deltas
      'item/agentMessage/delta' => AgentMessageDeltaEvent.fromParams(params),
      'item/reasoning/summaryTextDelta' =>
        ReasoningSummaryDeltaEvent.fromParams(params),
      'item/reasoning/textDelta' =>
        ReasoningTextDeltaEvent.fromParams(params),
      'item/commandExecution/outputDelta' =>
        CommandOutputDeltaEvent.fromParams(params),
      'item/fileChange/outputDelta' =>
        FileChangeOutputDeltaEvent.fromParams(params),
      'item/mcpToolCall/progress' =>
        McpToolCallProgressEvent.fromParams(params),

      // Legacy codex/event namespace (still emitted alongside new events)
      'codex/event/task_complete' => TaskCompleteEvent.fromParams(params),
      'codex/event/mcp_startup_complete' => const McpStartupCompleteEvent(),

      // Errors
      'error' => CodexErrorEvent.fromParams(params),

      // Everything else
      _ => UnknownCodexEvent(method: method, params: params),
    };
  }
}

// ---------------------------------------------------------------------------
// Thread lifecycle
// ---------------------------------------------------------------------------

class ThreadStartedEvent extends CodexEvent {
  final String threadId;
  final Map<String, dynamic> threadData;

  const ThreadStartedEvent({
    required this.threadId,
    required this.threadData,
  });

  factory ThreadStartedEvent.fromParams(Map<String, dynamic> params) {
    final thread = params['thread'] as Map<String, dynamic>? ?? {};
    return ThreadStartedEvent(
      threadId: thread['id'] as String? ?? '',
      threadData: thread,
    );
  }
}

class ThreadNameUpdatedEvent extends CodexEvent {
  final String threadId;
  final String name;

  const ThreadNameUpdatedEvent({
    required this.threadId,
    required this.name,
  });

  factory ThreadNameUpdatedEvent.fromParams(Map<String, dynamic> params) {
    return ThreadNameUpdatedEvent(
      threadId: params['threadId'] as String? ?? '',
      name: params['name'] as String? ?? '',
    );
  }
}

class ThreadCompactedEvent extends CodexEvent {
  final Map<String, dynamic> params;

  const ThreadCompactedEvent({required this.params});

  factory ThreadCompactedEvent.fromParams(Map<String, dynamic> params) {
    return ThreadCompactedEvent(params: params);
  }
}

// ---------------------------------------------------------------------------
// Turn lifecycle
// ---------------------------------------------------------------------------

class TurnStartedEvent extends CodexEvent {
  final String turnId;
  final Map<String, dynamic> turnData;

  const TurnStartedEvent({
    required this.turnId,
    required this.turnData,
  });

  factory TurnStartedEvent.fromParams(Map<String, dynamic> params) {
    final turn = params['turn'] as Map<String, dynamic>? ?? {};
    return TurnStartedEvent(
      turnId: turn['id'] as String? ?? '',
      turnData: turn,
    );
  }
}

class TurnCompletedEvent extends CodexEvent {
  final String turnId;
  final String status;
  final Map<String, dynamic> turnData;

  const TurnCompletedEvent({
    required this.turnId,
    required this.status,
    required this.turnData,
  });

  factory TurnCompletedEvent.fromParams(Map<String, dynamic> params) {
    final turn = params['turn'] as Map<String, dynamic>? ?? {};
    return TurnCompletedEvent(
      turnId: turn['id'] as String? ?? '',
      status: turn['status'] as String? ?? '',
      turnData: turn,
    );
  }
}

// ---------------------------------------------------------------------------
// Item lifecycle
// ---------------------------------------------------------------------------

class ItemStartedEvent extends CodexEvent {
  final String itemId;
  final String itemType;
  final Map<String, dynamic> itemData;

  const ItemStartedEvent({
    required this.itemId,
    required this.itemType,
    required this.itemData,
  });

  factory ItemStartedEvent.fromParams(Map<String, dynamic> params) {
    final item = params['item'] as Map<String, dynamic>? ?? {};
    return ItemStartedEvent(
      itemId: item['id'] as String? ?? '',
      itemType: item['type'] as String? ?? '',
      itemData: item,
    );
  }
}

class ItemCompletedEvent extends CodexEvent {
  final String itemId;
  final String itemType;
  final Map<String, dynamic> itemData;

  const ItemCompletedEvent({
    required this.itemId,
    required this.itemType,
    required this.itemData,
  });

  factory ItemCompletedEvent.fromParams(Map<String, dynamic> params) {
    final item = params['item'] as Map<String, dynamic>? ?? {};
    return ItemCompletedEvent(
      itemId: item['id'] as String? ?? '',
      itemType: item['type'] as String? ?? '',
      itemData: item,
    );
  }
}

// ---------------------------------------------------------------------------
// Streaming deltas
// ---------------------------------------------------------------------------

class AgentMessageDeltaEvent extends CodexEvent {
  final String itemId;
  final String delta;

  const AgentMessageDeltaEvent({
    required this.itemId,
    required this.delta,
  });

  factory AgentMessageDeltaEvent.fromParams(Map<String, dynamic> params) {
    return AgentMessageDeltaEvent(
      itemId: params['itemId'] as String? ?? '',
      delta: params['delta'] as String? ?? '',
    );
  }
}

class ReasoningSummaryDeltaEvent extends CodexEvent {
  final String itemId;
  final String delta;

  const ReasoningSummaryDeltaEvent({
    required this.itemId,
    required this.delta,
  });

  factory ReasoningSummaryDeltaEvent.fromParams(Map<String, dynamic> params) {
    return ReasoningSummaryDeltaEvent(
      itemId: params['itemId'] as String? ?? '',
      delta: params['delta'] as String? ?? '',
    );
  }
}

class ReasoningTextDeltaEvent extends CodexEvent {
  final String itemId;
  final String delta;

  const ReasoningTextDeltaEvent({
    required this.itemId,
    required this.delta,
  });

  factory ReasoningTextDeltaEvent.fromParams(Map<String, dynamic> params) {
    return ReasoningTextDeltaEvent(
      itemId: params['itemId'] as String? ?? '',
      delta: params['delta'] as String? ?? '',
    );
  }
}

class CommandOutputDeltaEvent extends CodexEvent {
  final String itemId;
  final String delta;

  const CommandOutputDeltaEvent({
    required this.itemId,
    required this.delta,
  });

  factory CommandOutputDeltaEvent.fromParams(Map<String, dynamic> params) {
    return CommandOutputDeltaEvent(
      itemId: params['itemId'] as String? ?? '',
      delta: params['delta'] as String? ?? '',
    );
  }
}

class FileChangeOutputDeltaEvent extends CodexEvent {
  final String itemId;
  final String delta;

  const FileChangeOutputDeltaEvent({
    required this.itemId,
    required this.delta,
  });

  factory FileChangeOutputDeltaEvent.fromParams(Map<String, dynamic> params) {
    return FileChangeOutputDeltaEvent(
      itemId: params['itemId'] as String? ?? '',
      delta: params['delta'] as String? ?? '',
    );
  }
}

class McpToolCallProgressEvent extends CodexEvent {
  final String itemId;
  final Map<String, dynamic> params;

  const McpToolCallProgressEvent({
    required this.itemId,
    required this.params,
  });

  factory McpToolCallProgressEvent.fromParams(Map<String, dynamic> params) {
    return McpToolCallProgressEvent(
      itemId: params['itemId'] as String? ?? '',
      params: params,
    );
  }
}

// ---------------------------------------------------------------------------
// Token usage
// ---------------------------------------------------------------------------

class TokenUsageUpdatedEvent extends CodexEvent {
  final CodexUsage usage;

  const TokenUsageUpdatedEvent({required this.usage});

  factory TokenUsageUpdatedEvent.fromParams(Map<String, dynamic> params) {
    return TokenUsageUpdatedEvent(
      usage: CodexUsage.fromJson(params),
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy codex/event namespace
// ---------------------------------------------------------------------------

class TaskCompleteEvent extends CodexEvent {
  final String? lastAgentMessage;
  final Map<String, dynamic> params;

  const TaskCompleteEvent({
    this.lastAgentMessage,
    required this.params,
  });

  factory TaskCompleteEvent.fromParams(Map<String, dynamic> params) {
    final msg = params['msg'] as Map<String, dynamic>? ?? {};
    return TaskCompleteEvent(
      lastAgentMessage: msg['last_agent_message'] as String?,
      params: params,
    );
  }
}

class McpStartupCompleteEvent extends CodexEvent {
  const McpStartupCompleteEvent();
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

class CodexErrorEvent extends CodexEvent {
  final String message;
  final Map<String, dynamic>? details;

  const CodexErrorEvent({required this.message, this.details});

  factory CodexErrorEvent.fromParams(Map<String, dynamic> params) {
    final message = params['message'] as String? ?? 'Unknown error';
    return CodexErrorEvent(message: message, details: params);
  }
}

// ---------------------------------------------------------------------------
// Unknown / catch-all
// ---------------------------------------------------------------------------

class UnknownCodexEvent extends CodexEvent {
  final String method;
  final Map<String, dynamic> params;

  const UnknownCodexEvent({required this.method, required this.params});
}

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

class CodexUsage {
  final int inputTokens;
  final int cachedInputTokens;
  final int outputTokens;

  const CodexUsage({
    required this.inputTokens,
    required this.cachedInputTokens,
    required this.outputTokens,
  });

  factory CodexUsage.fromJson(Map<String, dynamic> json) {
    // Support both the thread/tokenUsage/updated format and legacy format
    final usage = json['usage'] as Map<String, dynamic>? ?? json;
    return CodexUsage(
      inputTokens: usage['input_tokens'] as int? ??
          usage['inputTokens'] as int? ??
          0,
      cachedInputTokens: usage['cached_input_tokens'] as int? ??
          usage['cachedInputTokens'] as int? ??
          0,
      outputTokens: usage['output_tokens'] as int? ??
          usage['outputTokens'] as int? ??
          0,
    );
  }
}
