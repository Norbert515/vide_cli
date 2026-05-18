/// Configuration for the Gemini CLI wrapper.
class GeminiConfig {
  /// Model to use (e.g. 'gemini-2.5-pro', 'gemini-2.5-flash').
  final String? model;

  /// Working directory for the Gemini CLI subprocess.
  final String? workingDirectory;

  /// Session ID for resuming a previous session via `--resume`.
  final String? sessionId;

  /// Gemini API key. If null, Gemini CLI uses cached Google login
  /// credentials from `~/.gemini/` (LOGIN_WITH_GOOGLE auth type).
  final String? apiKey;

  /// Tool approval mode. Defaults to 'yolo' because headless mode has no
  /// stdin-based approval protocol — tools requiring confirmation are
  /// auto-denied unless a permissive mode is set.
  ///
  /// Options: 'default', 'auto_edit', 'yolo', 'plan'
  final String approvalMode;

  /// Custom system prompt / instructions.
  final String? systemPrompt;

  /// Sandbox mode setting.
  final String? sandbox;

  const GeminiConfig({
    this.model,
    this.workingDirectory,
    this.sessionId,
    this.apiKey,
    this.approvalMode = 'yolo',
    this.systemPrompt,
    this.sandbox,
  });

  /// Build CLI args for a single turn.
  ///
  /// Produces args like:
  /// `['-p', prompt, '-o', 'stream-json', '-m', model, '--approval-mode', 'yolo']`
  List<String> toCliArgs(String prompt) {
    final args = <String>[
      '-p',
      prompt,
      '-o',
      'stream-json',
      '--approval-mode',
      approvalMode,
    ];

    if (model != null) {
      args.addAll(['-m', model!]);
    }

    if (sessionId != null) {
      args.addAll(['--resume', sessionId!]);
    }

    if (sandbox != null) {
      args.addAll(['--sandbox', sandbox!]);
    }

    return args;
  }

  GeminiConfig copyWith({
    String? model,
    String? workingDirectory,
    String? sessionId,
    String? apiKey,
    String? approvalMode,
    String? systemPrompt,
    String? sandbox,
  }) {
    return GeminiConfig(
      model: model ?? this.model,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      sessionId: sessionId ?? this.sessionId,
      apiKey: apiKey ?? this.apiKey,
      approvalMode: approvalMode ?? this.approvalMode,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      sandbox: sandbox ?? this.sandbox,
    );
  }
}
