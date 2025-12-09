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
  });

  factory ClaudeConfig.defaults() => const ClaudeConfig();

  factory ClaudeConfig.fromJson(Map<String, dynamic> json) =>
      _$ClaudeConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeConfigToJson(this);

  List<String> toCliArgs({
    bool isFirstMessage = false,
    String? message,
    bool useJsonInput = false,
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

    // Use pipe mode with JSON streaming output
    // Input format depends on whether we're using attachments
    args.addAll([
      '-p', // Pipe mode
      '--output-format=stream-json',
      '--input-format=${useJsonInput ? 'stream-json' : 'text'}',
      '--verbose', // Required for stream-json with -p
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

    if (additionalFlags != null) {
      args.addAll(additionalFlags!);
    }

    // Add message as last argument if provided
    if (message != null) {
      args.add(message);
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
    );
  }
}
