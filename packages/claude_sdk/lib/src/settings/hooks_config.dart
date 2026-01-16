import 'package:json_annotation/json_annotation.dart';

part 'hooks_config.g.dart';

/// Hooks configuration for Claude Code.
///
/// Hooks allow running custom scripts before or after tool execution.
/// They can be used for validation, logging, or custom processing.
///
/// See: https://code.claude.com/docs/en/settings#hooks
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class HooksConfig {
  /// Hooks that run before tool execution.
  /// Map from tool pattern to hook command.
  /// Example: {"Bash": "echo 'Running command...'"}
  @JsonKey(name: 'PreToolUse')
  final dynamic preToolUse;

  /// Hooks that run after tool execution.
  @JsonKey(name: 'PostToolUse')
  final dynamic postToolUse;

  /// Hooks that run when a message is received.
  @JsonKey(name: 'PreMessage')
  final dynamic preMessage;

  /// Hooks that run when a response is about to be sent.
  @JsonKey(name: 'PostMessage')
  final dynamic postMessage;

  /// Hooks that run when a prompt is submitted.
  @JsonKey(name: 'PromptSubmit')
  final dynamic promptSubmit;

  /// Hooks that run when a session starts.
  @JsonKey(name: 'SessionStart')
  final dynamic sessionStart;

  /// Hooks that run when a session ends.
  @JsonKey(name: 'SessionEnd')
  final dynamic sessionEnd;

  const HooksConfig({
    this.preToolUse,
    this.postToolUse,
    this.preMessage,
    this.postMessage,
    this.promptSubmit,
    this.sessionStart,
    this.sessionEnd,
  });

  factory HooksConfig.empty() => const HooksConfig();

  factory HooksConfig.fromJson(Map<String, dynamic> json) =>
      _$HooksConfigFromJson(json);

  Map<String, dynamic> toJson() => _$HooksConfigToJson(this);

  HooksConfig copyWith({
    dynamic preToolUse,
    dynamic postToolUse,
    dynamic preMessage,
    dynamic postMessage,
    dynamic promptSubmit,
    dynamic sessionStart,
    dynamic sessionEnd,
  }) {
    return HooksConfig(
      preToolUse: preToolUse ?? this.preToolUse,
      postToolUse: postToolUse ?? this.postToolUse,
      preMessage: preMessage ?? this.preMessage,
      postMessage: postMessage ?? this.postMessage,
      promptSubmit: promptSubmit ?? this.promptSubmit,
      sessionStart: sessionStart ?? this.sessionStart,
      sessionEnd: sessionEnd ?? this.sessionEnd,
    );
  }
}

/// A typed hook definition for PreToolUse hooks.
///
/// PreToolUse hooks can be specified as:
/// - Simple string: "echo 'hello'"
/// - List of hook commands with matchers
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class PreToolUseHook {
  /// Pattern to match tool invocations.
  /// Example: "Bash", "Read", "*"
  final String matcher;

  /// List of hooks to run when pattern matches.
  final List<HookCommand> hooks;

  const PreToolUseHook({
    required this.matcher,
    required this.hooks,
  });

  factory PreToolUseHook.fromJson(Map<String, dynamic> json) =>
      _$PreToolUseHookFromJson(json);

  Map<String, dynamic> toJson() => _$PreToolUseHookToJson(this);
}

/// A single hook command definition.
@JsonSerializable(includeIfNull: false)
class HookCommand {
  /// Type of hook command.
  /// Values: "command"
  final String type;

  /// The command to execute.
  final String command;

  /// Timeout in milliseconds.
  final int? timeout;

  const HookCommand({
    required this.type,
    required this.command,
    this.timeout,
  });

  factory HookCommand.fromJson(Map<String, dynamic> json) =>
      _$HookCommandFromJson(json);

  Map<String, dynamic> toJson() => _$HookCommandToJson(this);
}
