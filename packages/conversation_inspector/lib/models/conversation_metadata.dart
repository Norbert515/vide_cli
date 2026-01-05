import 'dart:io';

/// Metadata for a Claude Code conversation.
///
/// This represents the information we can discover about a conversation
/// from the file system and history.jsonl.
class ConversationMetadata {
  final String sessionId;
  final String projectPath;
  final String encodedProjectPath;
  final String? displayText;
  final DateTime? timestamp;
  final DateTime? lastModified;
  final int? fileSize;

  const ConversationMetadata({
    required this.sessionId,
    required this.projectPath,
    required this.encodedProjectPath,
    this.displayText,
    this.timestamp,
    this.lastModified,
    this.fileSize,
  });

  /// Get the project name (last component of path).
  String get projectName {
    final parts = projectPath.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : projectPath;
  }

  /// Encode a project path to Claude's storage format.
  /// Example: "/Users/foo/my_project" -> "-Users-foo-my-project"
  static String encodeProjectPath(String path) {
    return path.replaceAll('/', '-').replaceAll('_', '-');
  }

  /// Decode a project path from Claude's storage format.
  /// Note: This is lossy since both / and _ become -.
  static String decodeProjectPath(String encoded) {
    if (encoded.startsWith('-')) {
      return encoded.replaceFirst('-', '/').replaceAll('-', '/');
    }
    return encoded.replaceAll('-', '/');
  }

  /// Get the full path to the conversation JSONL file.
  String getFilePath() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    return '$home/.claude/projects/$encodedProjectPath/$sessionId.jsonl';
  }

  /// Create from a history.jsonl entry.
  factory ConversationMetadata.fromHistoryEntry(Map<String, dynamic> json) {
    final projectPath = json['project'] as String? ?? '';
    return ConversationMetadata(
      sessionId: json['sessionId'] as String? ?? '',
      projectPath: projectPath,
      encodedProjectPath: encodeProjectPath(projectPath),
      displayText: json['display'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  /// Create from file system discovery.
  factory ConversationMetadata.fromFile(
    File file,
    String encodedProjectPath,
  ) {
    final fileName = file.uri.pathSegments.last;
    final sessionId = fileName.replaceAll('.jsonl', '');
    final stat = file.statSync();

    return ConversationMetadata(
      sessionId: sessionId,
      projectPath: decodeProjectPath(encodedProjectPath),
      encodedProjectPath: encodedProjectPath,
      lastModified: stat.modified,
      fileSize: stat.size,
    );
  }

  @override
  String toString() => 'ConversationMetadata($sessionId, $projectPath)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationMetadata &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          encodedProjectPath == other.encodedProjectPath;

  @override
  int get hashCode => sessionId.hashCode ^ encodedProjectPath.hashCode;
}
