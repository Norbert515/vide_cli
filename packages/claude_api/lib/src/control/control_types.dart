/// Control Protocol Types for Claude Code SDK
///
/// This implements the bidirectional control protocol used by the official
/// Python/TypeScript SDKs to enable hooks and permission callbacks.

/// Hook event types supported by the control protocol
enum HookEvent {
  preToolUse('PreToolUse'),
  postToolUse('PostToolUse'),
  userPromptSubmit('UserPromptSubmit'),
  stop('Stop'),
  subagentStop('SubagentStop'),
  preCompact('PreCompact');

  final String value;
  const HookEvent(this.value);

  static HookEvent? fromString(String value) {
    for (final event in values) {
      if (event.value == value) return event;
    }
    return null;
  }
}

/// Permission decision for hooks and permission callbacks
enum PermissionDecision {
  allow('allow'),
  deny('deny'),
  ask('ask');

  final String value;
  const PermissionDecision(this.value);
}

/// Permission behavior for can_use_tool responses
enum PermissionBehavior {
  allow('allow'),
  deny('deny');

  final String value;
  const PermissionBehavior(this.value);
}

/// Base class for hook input data
class HookInput {
  final String hookEventName;
  final String sessionId;
  final String transcriptPath;
  final String cwd;
  final String? permissionMode;

  const HookInput({
    required this.hookEventName,
    required this.sessionId,
    required this.transcriptPath,
    required this.cwd,
    this.permissionMode,
  });

  factory HookInput.fromJson(Map<String, dynamic> json) {
    final eventName = json['hook_event_name'] as String;

    // Route to specific subclass based on event type
    switch (eventName) {
      case 'PreToolUse':
        return PreToolUseHookInput.fromJson(json);
      case 'PostToolUse':
        return PostToolUseHookInput.fromJson(json);
      case 'UserPromptSubmit':
        return UserPromptSubmitHookInput.fromJson(json);
      case 'Stop':
      case 'SubagentStop':
        return StopHookInput.fromJson(json);
      case 'PreCompact':
        return PreCompactHookInput.fromJson(json);
      default:
        return HookInput._fromJsonBase(json);
    }
  }

  factory HookInput._fromJsonBase(Map<String, dynamic> json) {
    return HookInput(
      hookEventName: json['hook_event_name'] as String,
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: json['permission_mode'] as String?,
    );
  }
}

/// Input for PreToolUse hook events
class PreToolUseHookInput extends HookInput {
  final String toolName;
  final Map<String, dynamic> toolInput;

  const PreToolUseHookInput({
    required super.hookEventName,
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    super.permissionMode,
    required this.toolName,
    required this.toolInput,
  });

  factory PreToolUseHookInput.fromJson(Map<String, dynamic> json) {
    return PreToolUseHookInput(
      hookEventName: json['hook_event_name'] as String,
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: json['permission_mode'] as String?,
      toolName: json['tool_name'] as String? ?? '',
      toolInput: (json['tool_input'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Input for PostToolUse hook events
class PostToolUseHookInput extends HookInput {
  final String toolName;
  final Map<String, dynamic> toolInput;
  final dynamic toolResponse;

  const PostToolUseHookInput({
    required super.hookEventName,
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    super.permissionMode,
    required this.toolName,
    required this.toolInput,
    this.toolResponse,
  });

  factory PostToolUseHookInput.fromJson(Map<String, dynamic> json) {
    return PostToolUseHookInput(
      hookEventName: json['hook_event_name'] as String,
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: json['permission_mode'] as String?,
      toolName: json['tool_name'] as String? ?? '',
      toolInput: (json['tool_input'] as Map<String, dynamic>?) ?? {},
      toolResponse: json['tool_response'],
    );
  }
}

/// Input for UserPromptSubmit hook events
class UserPromptSubmitHookInput extends HookInput {
  final String prompt;

  const UserPromptSubmitHookInput({
    required super.hookEventName,
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    super.permissionMode,
    required this.prompt,
  });

  factory UserPromptSubmitHookInput.fromJson(Map<String, dynamic> json) {
    return UserPromptSubmitHookInput(
      hookEventName: json['hook_event_name'] as String,
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: json['permission_mode'] as String?,
      prompt: json['prompt'] as String? ?? '',
    );
  }
}

/// Input for Stop and SubagentStop hook events
class StopHookInput extends HookInput {
  final bool stopHookActive;

  const StopHookInput({
    required super.hookEventName,
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    super.permissionMode,
    required this.stopHookActive,
  });

  factory StopHookInput.fromJson(Map<String, dynamic> json) {
    return StopHookInput(
      hookEventName: json['hook_event_name'] as String,
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: json['permission_mode'] as String?,
      stopHookActive: json['stop_hook_active'] as bool? ?? false,
    );
  }
}

/// Input for PreCompact hook events
class PreCompactHookInput extends HookInput {
  final String trigger; // 'manual' or 'auto'
  final String? customInstructions;

  const PreCompactHookInput({
    required super.hookEventName,
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    super.permissionMode,
    required this.trigger,
    this.customInstructions,
  });

  factory PreCompactHookInput.fromJson(Map<String, dynamic> json) {
    return PreCompactHookInput(
      hookEventName: json['hook_event_name'] as String,
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: json['permission_mode'] as String?,
      trigger: json['trigger'] as String? ?? 'auto',
      customInstructions: json['custom_instructions'] as String?,
    );
  }
}

/// Output from a hook callback
class HookOutput {
  /// If false, stops the entire session
  final bool continueExecution;

  /// Message shown when stopping
  final String? stopReason;

  /// Hide stdout from transcript
  final bool suppressOutput;

  /// Message injected into conversation
  final String? systemMessage;

  /// Hook-specific output (for PreToolUse)
  final HookSpecificOutput? hookSpecificOutput;

  const HookOutput({
    this.continueExecution = true,
    this.stopReason,
    this.suppressOutput = false,
    this.systemMessage,
    this.hookSpecificOutput,
  });

  /// Create an output that allows the operation
  factory HookOutput.allow() => const HookOutput();

  /// Create an output that denies the operation
  factory HookOutput.deny(String reason) => HookOutput(
    hookSpecificOutput: HookSpecificOutput(
      hookEventName: 'PreToolUse',
      permissionDecision: PermissionDecision.deny,
      permissionDecisionReason: reason,
    ),
  );

  /// Create an output that stops the session
  factory HookOutput.stop(String reason) => HookOutput(
    continueExecution: false,
    stopReason: reason,
  );

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    // Use 'continue' not 'continueExecution' for CLI compatibility
    if (!continueExecution) {
      result['continue'] = false;
    }
    if (stopReason != null) {
      result['stopReason'] = stopReason;
    }
    if (suppressOutput) {
      result['suppressOutput'] = true;
    }
    if (systemMessage != null) {
      result['systemMessage'] = systemMessage;
    }
    if (hookSpecificOutput != null) {
      result['hookSpecificOutput'] = hookSpecificOutput!.toJson();
    }

    return result;
  }
}

/// Hook-specific output for PreToolUse hooks
class HookSpecificOutput {
  final String hookEventName;
  final PermissionDecision permissionDecision;
  final String? permissionDecisionReason;
  final Map<String, dynamic>? updatedInput;
  final String? additionalContext;

  const HookSpecificOutput({
    required this.hookEventName,
    required this.permissionDecision,
    this.permissionDecisionReason,
    this.updatedInput,
    this.additionalContext,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'hookEventName': hookEventName,
      'permissionDecision': permissionDecision.value,
    };

    if (permissionDecisionReason != null) {
      result['permissionDecisionReason'] = permissionDecisionReason;
    }
    if (updatedInput != null) {
      result['updatedInput'] = updatedInput;
    }
    if (additionalContext != null) {
      result['additionalContext'] = additionalContext;
    }

    return result;
  }
}

/// Permission result for can_use_tool callbacks
sealed class PermissionResult {
  const PermissionResult();

  Map<String, dynamic> toJson();
}

/// Allow the tool to execute
class PermissionResultAllow extends PermissionResult {
  final Map<String, dynamic>? updatedInput;
  final List<PermissionUpdate>? updatedPermissions;

  const PermissionResultAllow({
    this.updatedInput,
    this.updatedPermissions,
  });

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'behavior': 'allow',
    };
    if (updatedInput != null) {
      result['updatedInput'] = updatedInput;
    }
    if (updatedPermissions != null) {
      result['updatedPermissions'] =
          updatedPermissions!.map((p) => p.toJson()).toList();
    }
    return result;
  }
}

/// Deny the tool execution
class PermissionResultDeny extends PermissionResult {
  final String message;
  final bool interrupt;

  const PermissionResultDeny({
    required this.message,
    this.interrupt = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'behavior': 'deny',
    'message': message,
    'interrupt': interrupt,
  };
}

/// Permission update for modifying permission rules
class PermissionUpdate {
  final String type; // addRules, replaceRules, removeRules, setMode, etc.
  final String? destination;
  final List<Map<String, dynamic>>? rules;
  final String? mode;
  final List<String>? directories;

  const PermissionUpdate({
    required this.type,
    this.destination,
    this.rules,
    this.mode,
    this.directories,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'type': type,
    };
    if (destination != null) result['destination'] = destination;
    if (rules != null) result['rules'] = rules;
    if (mode != null) result['mode'] = mode;
    if (directories != null) result['directories'] = directories;
    return result;
  }
}

/// Context passed to permission callbacks
class ToolPermissionContext {
  final List<String>? permissionSuggestions;
  final String? blockedPath;

  const ToolPermissionContext({
    this.permissionSuggestions,
    this.blockedPath,
  });

  factory ToolPermissionContext.fromJson(Map<String, dynamic> json) {
    return ToolPermissionContext(
      permissionSuggestions: (json['permission_suggestions'] as List<dynamic>?)
          ?.cast<String>(),
      blockedPath: json['blocked_path'] as String?,
    );
  }
}

/// Callback type for hooks
typedef HookCallback = Future<HookOutput> Function(
  HookInput input,
  String? toolUseId,
);

/// Callback type for permission checks
typedef CanUseToolCallback = Future<PermissionResult> Function(
  String toolName,
  Map<String, dynamic> input,
  ToolPermissionContext context,
);

/// Hook matcher configuration
class HookMatcher {
  /// Regex pattern to match tool names (null matches all)
  final String? matcher;

  /// The callback function to execute
  final HookCallback callback;

  /// Timeout in seconds (default 60)
  final int timeout;

  const HookMatcher({
    this.matcher,
    required this.callback,
    this.timeout = 60,
  });
}
