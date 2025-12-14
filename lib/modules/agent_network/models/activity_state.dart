import 'package:claude_api/claude_api.dart';
import '../service/activity_classifier.dart';

/// Represents the current activity state of an agent.
/// Tracks what the agent is doing and for how long.
class ActivityState {
  /// The current tool being executed (null if thinking/idle)
  final ToolUseResponse? currentTool;

  /// Classified activity message for the current tool
  final ActivityMessage? activityMessage;

  /// When the current activity started (for duration tracking)
  final DateTime? activityStartTime;

  /// Whether the agent is currently thinking (no tool active)
  final bool isThinking;

  /// When thinking started
  final DateTime? thinkingStartTime;

  /// Number of tools currently in progress (for "+N more" indicator)
  final int pendingToolCount;

  const ActivityState({
    this.currentTool,
    this.activityMessage,
    this.activityStartTime,
    this.isThinking = false,
    this.thinkingStartTime,
    this.pendingToolCount = 0,
  });

  /// Creates an empty/idle state
  const ActivityState.idle()
      : currentTool = null,
        activityMessage = null,
        activityStartTime = null,
        isThinking = false,
        thinkingStartTime = null,
        pendingToolCount = 0;

  /// Creates a thinking state
  ActivityState.thinking({DateTime? startTime})
      : currentTool = null,
        activityMessage = null,
        activityStartTime = null,
        isThinking = true,
        thinkingStartTime = startTime ?? DateTime.now(),
        pendingToolCount = 0;

  /// Creates a state for active tool execution
  factory ActivityState.forTool(ToolUseResponse tool, {int pendingCount = 0}) {
    final message = ActivityClassifier.classifyToolUse(tool);
    return ActivityState(
      currentTool: tool,
      activityMessage: message,
      activityStartTime: DateTime.now(),
      isThinking: false,
      thinkingStartTime: null,
      pendingToolCount: pendingCount,
    );
  }

  /// Gets the duration of the current activity
  Duration? get activityDuration {
    if (activityStartTime != null) {
      return DateTime.now().difference(activityStartTime!);
    }
    return null;
  }

  /// Gets the duration of thinking
  Duration? get thinkingDuration {
    if (thinkingStartTime != null) {
      return DateTime.now().difference(thinkingStartTime!);
    }
    return null;
  }

  /// Gets formatted thinking duration string (e.g., "3s", "1m 23s")
  String? get formattedThinkingDuration {
    final duration = thinkingDuration;
    if (duration == null) return null;

    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = duration.inMinutes;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  /// Creates a copy with updated values
  ActivityState copyWith({
    ToolUseResponse? currentTool,
    ActivityMessage? activityMessage,
    DateTime? activityStartTime,
    bool? isThinking,
    DateTime? thinkingStartTime,
    int? pendingToolCount,
  }) {
    return ActivityState(
      currentTool: currentTool ?? this.currentTool,
      activityMessage: activityMessage ?? this.activityMessage,
      activityStartTime: activityStartTime ?? this.activityStartTime,
      isThinking: isThinking ?? this.isThinking,
      thinkingStartTime: thinkingStartTime ?? this.thinkingStartTime,
      pendingToolCount: pendingToolCount ?? this.pendingToolCount,
    );
  }
}

/// Extracts activity state from a streaming conversation message
ActivityState extractActivityState(ConversationMessage? message) {
  if (message == null || !message.isStreaming) {
    return const ActivityState.idle();
  }

  // Track tool calls and their results
  final activeTools = <String, ToolUseResponse>{};
  final completedToolIds = <String>{};

  for (final response in message.responses) {
    if (response is ToolUseResponse && response.toolUseId != null) {
      activeTools[response.toolUseId!] = response;
    } else if (response is ToolResultResponse) {
      completedToolIds.add(response.toolUseId);
    }
  }

  // Find tools that haven't completed yet
  final pendingTools = <ToolUseResponse>[];
  for (final entry in activeTools.entries) {
    if (!completedToolIds.contains(entry.key)) {
      pendingTools.add(entry.value);
    }
  }

  if (pendingTools.isEmpty) {
    // No active tools - agent is thinking
    // Find when the last tool completed or when streaming started
    DateTime? thinkingStart;

    // If we have responses, thinking started after the last one
    if (message.responses.isNotEmpty) {
      final lastResponse = message.responses.last;
      thinkingStart = lastResponse.timestamp;
    }

    return ActivityState.thinking(startTime: thinkingStart);
  }

  // Return the most recent pending tool with count of others
  final currentTool = pendingTools.last;
  final pendingCount = pendingTools.length - 1;

  return ActivityState.forTool(currentTool, pendingCount: pendingCount);
}
