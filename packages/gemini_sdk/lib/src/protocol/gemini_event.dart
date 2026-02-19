/// Gemini CLI stream-json event types.
///
/// When invoked with `--output-format stream-json`, Gemini CLI emits
/// newline-delimited JSON events to stdout. Each event has a `type` field.
sealed class GeminiEvent {
  final DateTime timestamp;

  const GeminiEvent({required this.timestamp});

  /// Parse a JSON map (from a single JSONL line) into a typed [GeminiEvent].
  factory GeminiEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final ts =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();

    return switch (type) {
      'init' => GeminiInitEvent.fromJson(json, ts),
      'message' => GeminiMessageEvent.fromJson(json, ts),
      'tool_use' => GeminiToolUseEvent.fromJson(json, ts),
      'tool_result' => GeminiToolResultEvent.fromJson(json, ts),
      'error' => GeminiErrorEvent.fromJson(json, ts),
      'result' => GeminiResultEvent.fromJson(json, ts),
      _ => GeminiUnknownEvent(type: type, data: json, timestamp: ts),
    };
  }
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

/// Emitted once at the start of a turn. Contains session and model info.
class GeminiInitEvent extends GeminiEvent {
  final String sessionId;
  final String? model;
  final Map<String, dynamic> data;

  const GeminiInitEvent({
    required this.sessionId,
    this.model,
    required this.data,
    required super.timestamp,
  });

  factory GeminiInitEvent.fromJson(Map<String, dynamic> json, DateTime ts) {
    return GeminiInitEvent(
      sessionId: json['session_id'] as String? ?? '',
      model: json['model'] as String?,
      data: json,
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

/// A message chunk (streaming text from the model or a full message).
class GeminiMessageEvent extends GeminiEvent {
  final String role;
  final String content;
  final bool isDelta;

  const GeminiMessageEvent({
    required this.role,
    required this.content,
    required this.isDelta,
    required super.timestamp,
  });

  factory GeminiMessageEvent.fromJson(Map<String, dynamic> json, DateTime ts) {
    return GeminiMessageEvent(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      isDelta: json['delta'] as bool? ?? false,
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Tool use
// ---------------------------------------------------------------------------

/// The model is invoking a tool.
class GeminiToolUseEvent extends GeminiEvent {
  final String toolName;
  final String toolId;
  final Map<String, dynamic> parameters;

  const GeminiToolUseEvent({
    required this.toolName,
    required this.toolId,
    required this.parameters,
    required super.timestamp,
  });

  factory GeminiToolUseEvent.fromJson(Map<String, dynamic> json, DateTime ts) {
    return GeminiToolUseEvent(
      toolName: json['tool_name'] as String? ?? '',
      toolId: json['tool_id'] as String? ?? '',
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Tool result
// ---------------------------------------------------------------------------

/// The result of a tool invocation.
class GeminiToolResultEvent extends GeminiEvent {
  final String toolId;
  final String status;
  final String output;

  const GeminiToolResultEvent({
    required this.toolId,
    required this.status,
    required this.output,
    required super.timestamp,
  });

  factory GeminiToolResultEvent.fromJson(
    Map<String, dynamic> json,
    DateTime ts,
  ) {
    return GeminiToolResultEvent(
      toolId: json['tool_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      output: json['output'] as String? ?? '',
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

/// An error event from the CLI.
class GeminiErrorEvent extends GeminiEvent {
  final String severity;
  final String message;
  final Map<String, dynamic>? details;

  const GeminiErrorEvent({
    required this.severity,
    required this.message,
    this.details,
    required super.timestamp,
  });

  factory GeminiErrorEvent.fromJson(Map<String, dynamic> json, DateTime ts) {
    return GeminiErrorEvent(
      severity: json['severity'] as String? ?? 'error',
      message: json['message'] as String? ?? 'Unknown error',
      details: json,
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Result (turn completion)
// ---------------------------------------------------------------------------

/// Emitted at the end of a turn with final status and token statistics.
class GeminiResultEvent extends GeminiEvent {
  final String status;
  final GeminiStats? stats;
  final Map<String, dynamic> data;

  const GeminiResultEvent({
    required this.status,
    this.stats,
    required this.data,
    required super.timestamp,
  });

  factory GeminiResultEvent.fromJson(Map<String, dynamic> json, DateTime ts) {
    final statsJson = json['stats'] as Map<String, dynamic>?;
    return GeminiResultEvent(
      status: json['status'] as String? ?? '',
      stats: statsJson != null ? GeminiStats.fromJson(statsJson) : null,
      data: json,
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Unknown / catch-all
// ---------------------------------------------------------------------------

/// An event type not recognized by this SDK version.
class GeminiUnknownEvent extends GeminiEvent {
  final String type;
  final Map<String, dynamic> data;

  const GeminiUnknownEvent({
    required this.type,
    required this.data,
    required super.timestamp,
  });
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// Token usage and timing statistics from a completed turn.
class GeminiStats {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final int durationMs;

  const GeminiStats({
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.durationMs,
  });

  factory GeminiStats.fromJson(Map<String, dynamic> json) {
    return GeminiStats(
      totalTokens: json['total_tokens'] as int? ?? 0,
      inputTokens: json['input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
    );
  }
}
