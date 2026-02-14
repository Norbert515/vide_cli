/// Codex CLI JSONL event types.
///
/// These represent the structured events emitted by `codex exec --json`.
sealed class CodexEvent {
  const CodexEvent();

  factory CodexEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    return switch (type) {
      'thread.started' => ThreadStartedEvent.fromJson(json),
      'turn.started' => const TurnStartedEvent(),
      'turn.completed' => TurnCompletedEvent.fromJson(json),
      'turn.failed' => TurnFailedEvent.fromJson(json),
      'item.started' ||
      'item.updated' ||
      'item.completed' => ItemEvent.fromJson(type, json),
      'error' => CodexErrorEvent.fromJson(json),
      _ => UnknownCodexEvent(json),
    };
  }
}

class ThreadStartedEvent extends CodexEvent {
  final String threadId;

  const ThreadStartedEvent({required this.threadId});

  factory ThreadStartedEvent.fromJson(Map<String, dynamic> json) {
    return ThreadStartedEvent(threadId: json['thread_id'] as String? ?? '');
  }
}

class TurnStartedEvent extends CodexEvent {
  const TurnStartedEvent();
}

class TurnCompletedEvent extends CodexEvent {
  final CodexUsage? usage;

  const TurnCompletedEvent({this.usage});

  factory TurnCompletedEvent.fromJson(Map<String, dynamic> json) {
    final usageJson = json['usage'] as Map<String, dynamic>?;
    return TurnCompletedEvent(
      usage: usageJson != null ? CodexUsage.fromJson(usageJson) : null,
    );
  }
}

class TurnFailedEvent extends CodexEvent {
  final String? error;
  final Map<String, dynamic>? details;

  const TurnFailedEvent({this.error, this.details});

  factory TurnFailedEvent.fromJson(Map<String, dynamic> json) {
    final errorData = json['error'];
    String? errorMessage;
    Map<String, dynamic>? details;

    if (errorData is String) {
      errorMessage = errorData;
    } else if (errorData is Map<String, dynamic>) {
      errorMessage = errorData['message'] as String?;
      details = errorData;
    }

    return TurnFailedEvent(error: errorMessage, details: details);
  }
}

class ItemEvent extends CodexEvent {
  /// One of 'item.started', 'item.updated', 'item.completed'
  final String eventType;
  final String itemId;

  /// One of 'agent_message', 'command_execution', 'file_change',
  /// 'mcp_tool_call', 'reasoning', 'web_search', 'plan_update'
  final String itemType;
  final String? status;
  final Map<String, dynamic> data;

  const ItemEvent({
    required this.eventType,
    required this.itemId,
    required this.itemType,
    this.status,
    required this.data,
  });

  factory ItemEvent.fromJson(String eventType, Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>? ?? {};
    return ItemEvent(
      eventType: eventType,
      itemId: item['id'] as String? ?? '',
      itemType: item['type'] as String? ?? '',
      status: item['status'] as String?,
      data: item,
    );
  }

  bool get isStarted => eventType == 'item.started';
  bool get isUpdated => eventType == 'item.updated';
  bool get isCompleted => eventType == 'item.completed';
}

class CodexErrorEvent extends CodexEvent {
  final String message;
  final Map<String, dynamic>? details;

  const CodexErrorEvent({required this.message, this.details});

  factory CodexErrorEvent.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is String) {
      return CodexErrorEvent(message: error);
    } else if (error is Map<String, dynamic>) {
      return CodexErrorEvent(
        message: error['message'] as String? ?? 'Unknown error',
        details: error,
      );
    }
    return CodexErrorEvent(
      message: json['message'] as String? ?? 'Unknown error',
      details: json,
    );
  }
}

class UnknownCodexEvent extends CodexEvent {
  final Map<String, dynamic> rawData;
  const UnknownCodexEvent(this.rawData);
}

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
    return CodexUsage(
      inputTokens: json['input_tokens'] as int? ?? 0,
      cachedInputTokens: json['cached_input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
    );
  }
}
