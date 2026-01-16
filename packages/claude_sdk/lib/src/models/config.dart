import 'package:json_annotation/json_annotation.dart';

part 'config.g.dart';

@JsonSerializable()
class ClaudeConfig {
  final String? model;
  final Duration timeout;
  final int retryAttempts;
  final Duration retryDelay;
  final bool verbose;
  final String? appendSystemPrompt;
  final double? temperature;
  final int? maxTokens;
  final List<String>? additionalFlags;
  final String? sessionId;
  final String? permissionMode;
  final String? workingDirectory;
  final List<String>? allowedTools;
  final List<String>? disallowedTools;
  final int? maxTurns;
  final List<String>? settingSources;

  /// Whether to enable streaming of partial messages.
  /// When true, text is streamed character-by-character as it's generated.
  /// When false, only complete messages are returned.
  /// Defaults to true.
  final bool enableStreaming;

  /// Session ID to resume/fork from.
  /// When set with [forkSession] = true, creates a new session branched from this one.
  /// Different from [sessionId] which is the ID for the new session.
  final String? resumeSessionId;

  /// Whether to fork the session when resuming.
  /// When true, adds --fork-session flag along with --resume [resumeSessionId].
  /// The new session will start with the full conversation history from the source.
  final bool forkSession;

  const ClaudeConfig({
    this.model,
    this.timeout = const Duration(seconds: 120),
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.verbose = false,
    this.appendSystemPrompt,
    this.temperature,
    this.maxTokens,
    this.additionalFlags,
    this.sessionId,
    this.permissionMode,
    this.workingDirectory,
    this.allowedTools,
    this.disallowedTools,
    this.maxTurns,
    this.settingSources,
    this.enableStreaming = true,
    this.resumeSessionId,
    this.forkSession = false,
  });

  factory ClaudeConfig.defaults() => const ClaudeConfig();

  factory ClaudeConfig.fromJson(Map<String, dynamic> json) =>
      _$ClaudeConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeConfigToJson(this);

  List<String> toCliArgs({
    bool isFirstMessage = false,
    bool hasPermissionCallback = false,
  }) {
    final args = <String>[];

    // Session management
    // Handle forking from another session (takes priority over normal session handling)
    if (resumeSessionId != null && forkSession) {
      // Fork: resume from source session but with --fork-session to branch
      // Note: --session-id cannot be used with --resume, so Claude auto-generates
      // the new session ID. We capture it from the response and update config.
      args.addAll(['--resume', resumeSessionId!]);
      args.add('--fork-session');
    } else if (sessionId != null) {
      // Normal session handling: Use --session-id for new sessions, --resume for existing sessions
      if (isFirstMessage) {
        args.addAll(['--session-id=$sessionId']);
      } else {
        args.addAll(['--resume', sessionId!]);
      }
    }

    // Control protocol mode: bidirectional stream-json communication
    args.addAll([
      '--output-format=stream-json',
      '--input-format=stream-json',
      '--verbose',
    ]);

    // Enable streaming of partial messages if configured
    if (enableStreaming) {
      args.add('--include-partial-messages');
    }

    // If we have a permission callback, tell CLI to send permission requests via stdio
    if (hasPermissionCallback) {
      args.addAll(['--permission-prompt-tool', 'stdio']);
    }

    if (model != null) {
      args.addAll(['--model', model!]);
    }

    if (appendSystemPrompt != null) {
      args.addAll(['--append-system-prompt', appendSystemPrompt!]);
    }

    if (temperature != null) {
      args.addAll(['--temperature', temperature.toString()]);
    }

    if (maxTokens != null) {
      args.addAll(['--max-tokens', maxTokens.toString()]);
    }

    if (permissionMode != null) {
      args.addAll(['--permission-mode', permissionMode!]);
    }

    if (allowedTools != null && allowedTools!.isNotEmpty) {
      args.addAll(['--allowed-tools', allowedTools!.join(',')]);
    }

    if (disallowedTools != null && disallowedTools!.isNotEmpty) {
      args.addAll(['--disallowed-tools', disallowedTools!.join(',')]);
    }

    if (maxTurns != null) {
      args.addAll(['--max-turns', maxTurns.toString()]);
    }

    if (settingSources != null && settingSources!.isNotEmpty) {
      args.addAll(['--setting-sources', settingSources!.join(',')]);
    }

    if (additionalFlags != null) {
      args.addAll(additionalFlags!);
    }

    return args;
  }

  ClaudeConfig copyWith({
    String? model,
    Duration? timeout,
    int? retryAttempts,
    Duration? retryDelay,
    bool? verbose,
    String? appendSystemPrompt,
    double? temperature,
    int? maxTokens,
    List<String>? additionalFlags,
    String? sessionId,
    String? permissionMode,
    String? workingDirectory,
    List<String>? allowedTools,
    List<String>? disallowedTools,
    int? maxTurns,
    List<String>? settingSources,
    bool? enableStreaming,
    String? resumeSessionId,
    bool? forkSession,
  }) {
    return ClaudeConfig(
      model: model ?? this.model,
      timeout: timeout ?? this.timeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      verbose: verbose ?? this.verbose,
      appendSystemPrompt: appendSystemPrompt ?? this.appendSystemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      additionalFlags: additionalFlags ?? this.additionalFlags,
      sessionId: sessionId ?? this.sessionId,
      permissionMode: permissionMode ?? this.permissionMode,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      allowedTools: allowedTools ?? this.allowedTools,
      disallowedTools: disallowedTools ?? this.disallowedTools,
      maxTurns: maxTurns ?? this.maxTurns,
      settingSources: settingSources ?? this.settingSources,
      enableStreaming: enableStreaming ?? this.enableStreaming,
      resumeSessionId: resumeSessionId ?? this.resumeSessionId,
      forkSession: forkSession ?? this.forkSession,
    );
  }
}
