/// Permission request from Claude Code hook
class PermissionRequest {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String cwd;
  final DateTime timestamp;
  final String? inferredPattern;

  PermissionRequest({
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    required this.cwd,
    DateTime? timestamp,
    this.inferredPattern,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      requestId: '',
      toolName: json['tool_name'] as String,
      toolInput: json['tool_input'] as Map<String, dynamic>,
      cwd: json['cwd'] as String,
    );
  }

  PermissionRequest copyWith({String? requestId, String? inferredPattern}) {
    return PermissionRequest(
      requestId: requestId ?? this.requestId,
      toolName: toolName,
      toolInput: toolInput,
      cwd: cwd,
      timestamp: timestamp,
      inferredPattern: inferredPattern ?? this.inferredPattern,
    );
  }

  String get displayAction {
    switch (toolName) {
      case 'Bash':
        return 'Run: ${toolInput['command']}';
      case 'Write':
        return 'Write: ${toolInput['file_path']}';
      case 'Edit':
        return 'Edit: ${toolInput['file_path']}';
      case 'MultiEdit':
        return 'MultiEdit: ${toolInput['file_path']}';
      case 'WebFetch':
        return 'Fetch: ${toolInput['url']}';
      case 'WebSearch':
        return 'Search: ${toolInput['query']}';
      default:
        return 'Use $toolName';
    }
  }
}

/// Permission response to Claude Code hook
class PermissionResponse {
  final String decision;
  final String? reason;
  final bool remember;

  PermissionResponse({
    required this.decision,
    this.reason,
    required this.remember,
  });

  Map<String, dynamic> toJson() => {
        'decision': decision,
        if (reason != null) 'reason': reason,
        'remember': remember,
      };
}
