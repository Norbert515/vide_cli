class CodexConfig {
  final String? model;
  final String? profile;
  final String approvalPolicy;
  final String sandboxMode;
  final String? workingDirectory;
  final String? sessionId;
  final String? appendSystemPrompt;
  final List<String>? additionalFlags;
  final bool fullAuto;
  final List<String>? additionalDirs;

  const CodexConfig({
    this.model,
    this.profile,
    this.approvalPolicy = 'on-request',
    this.sandboxMode = 'workspace-write',
    this.workingDirectory,
    this.sessionId,
    this.appendSystemPrompt,
    this.additionalFlags,
    this.fullAuto = true,
    this.additionalDirs,
  });

  List<String> toCliArgs({bool isResume = false, String? resumeThreadId}) {
    // Codex CLI expects: codex exec [FLAGS] [resume <id>] [prompt]
    // All flags must come before the resume subcommand.
    final args = <String>['exec'];

    args.add('--json');

    if (fullAuto) {
      args.add('--full-auto');
    }

    if (model != null) {
      args.addAll(['--model', model!]);
    }

    if (profile != null) {
      args.addAll(['--profile', profile!]);
    }

    if (!fullAuto) {
      args.addAll(['--ask-for-approval', approvalPolicy]);
    }

    if (sandboxMode != 'workspace-write') {
      args.addAll(['--sandbox', sandboxMode]);
    }

    if (appendSystemPrompt != null) {
      args.addAll(['-c', 'instructions.append=$appendSystemPrompt']);
    }

    if (additionalDirs != null) {
      for (final dir in additionalDirs!) {
        args.addAll(['--add-dir', dir]);
      }
    }

    if (additionalFlags != null) {
      args.addAll(additionalFlags!);
    }

    // resume subcommand goes after all flags
    if (isResume && resumeThreadId != null) {
      args.add('resume');
      args.add(resumeThreadId);
    }

    return args;
  }

  CodexConfig copyWith({
    String? model,
    String? profile,
    String? approvalPolicy,
    String? sandboxMode,
    String? workingDirectory,
    String? sessionId,
    String? appendSystemPrompt,
    List<String>? additionalFlags,
    bool? fullAuto,
    List<String>? additionalDirs,
  }) {
    return CodexConfig(
      model: model ?? this.model,
      profile: profile ?? this.profile,
      approvalPolicy: approvalPolicy ?? this.approvalPolicy,
      sandboxMode: sandboxMode ?? this.sandboxMode,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      sessionId: sessionId ?? this.sessionId,
      appendSystemPrompt: appendSystemPrompt ?? this.appendSystemPrompt,
      additionalFlags: additionalFlags ?? this.additionalFlags,
      fullAuto: fullAuto ?? this.fullAuto,
      additionalDirs: additionalDirs ?? this.additionalDirs,
    );
  }
}
