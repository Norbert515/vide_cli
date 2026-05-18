class CodexConfig {
  final String? model;
  final String? profile;
  final String sandboxMode;
  final String? workingDirectory;
  final String? sessionId;
  final String? appendSystemPrompt;
  final bool skipGitRepoCheck;
  final List<String>? additionalDirs;
  final String approvalPolicy;

  const CodexConfig({
    this.model,
    this.profile,
    this.sandboxMode = 'workspace-write',
    this.workingDirectory,
    this.sessionId,
    this.appendSystemPrompt,
    this.skipGitRepoCheck = false,
    this.additionalDirs,
    this.approvalPolicy = 'on-failure',
  });

  /// Build the params map for the `thread/start` JSON-RPC request.
  Map<String, dynamic> toThreadStartParams() {
    final params = <String, dynamic>{};

    if (workingDirectory != null) {
      params['cwd'] = workingDirectory;
    }

    params['sandbox'] = sandboxMode;
    params['approvalPolicy'] = approvalPolicy;

    if (model != null) {
      params['model'] = model;
    }

    if (appendSystemPrompt != null) {
      params['developerInstructions'] = appendSystemPrompt;
    }

    return params;
  }

  CodexConfig copyWith({
    String? model,
    String? profile,
    String? sandboxMode,
    String? workingDirectory,
    String? sessionId,
    String? appendSystemPrompt,
    bool? skipGitRepoCheck,
    List<String>? additionalDirs,
    String? approvalPolicy,
  }) {
    return CodexConfig(
      model: model ?? this.model,
      profile: profile ?? this.profile,
      sandboxMode: sandboxMode ?? this.sandboxMode,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      sessionId: sessionId ?? this.sessionId,
      appendSystemPrompt: appendSystemPrompt ?? this.appendSystemPrompt,
      skipGitRepoCheck: skipGitRepoCheck ?? this.skipGitRepoCheck,
      additionalDirs: additionalDirs ?? this.additionalDirs,
      approvalPolicy: approvalPolicy ?? this.approvalPolicy,
    );
  }
}
