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
  });

  factory ClaudeConfig.defaults() => const ClaudeConfig();

  factory ClaudeConfig.fromJson(Map<String, dynamic> json) =>
      _$ClaudeConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeConfigToJson(this);

  List<String> toCliArgs({
    bool isFirstMessage = false,
  }) {
    final args = <String>[];

    // Session management
    if (sessionId != null) {
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
    );
  }
}
