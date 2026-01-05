import 'dart:convert';
import 'dart:io';

import '../models/conversation_metadata.dart';

/// Service for discovering Claude Code conversations on the local filesystem.
///
/// Scans ~/.claude/projects/ for conversation JSONL files and optionally
/// reads ~/.claude/history.jsonl for additional metadata.
class ConversationDiscoveryService {
  final String? _claudeDirOverride;

  ConversationDiscoveryService({String? claudeDir}) : _claudeDirOverride = claudeDir;

  /// Get the Claude directory path.
  String get claudeDir {
    if (_claudeDirOverride != null) return _claudeDirOverride;
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw StateError('Could not determine home directory');
    }
    return '$home/.claude';
  }

  /// Discover all conversations from the filesystem.
  ///
  /// Scans ~/.claude/projects/ for all .jsonl files and returns
  /// metadata for each conversation found.
  Future<List<ConversationMetadata>> discoverAllConversations() async {
    final projectsDir = Directory('$claudeDir/projects');
    if (!await projectsDir.exists()) {
      return [];
    }

    final conversations = <ConversationMetadata>[];
    final historyMetadata = await _loadHistoryMetadata();

    await for (final projectEntity in projectsDir.list()) {
      if (projectEntity is! Directory) continue;

      final encodedProjectPath = projectEntity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;

      await for (final fileEntity in projectEntity.list()) {
        if (fileEntity is! File) continue;
        if (!fileEntity.path.endsWith('.jsonl')) continue;

        final metadata = ConversationMetadata.fromFile(
          fileEntity,
          encodedProjectPath,
        );

        // Merge with history metadata if available
        final historyKey = '${metadata.sessionId}:${metadata.encodedProjectPath}';
        final historyEntry = historyMetadata[historyKey];

        if (historyEntry != null) {
          conversations.add(ConversationMetadata(
            sessionId: metadata.sessionId,
            projectPath: historyEntry.projectPath.isNotEmpty
                ? historyEntry.projectPath
                : metadata.projectPath,
            encodedProjectPath: metadata.encodedProjectPath,
            displayText: historyEntry.displayText,
            timestamp: historyEntry.timestamp,
            lastModified: metadata.lastModified,
            fileSize: metadata.fileSize,
          ));
        } else {
          conversations.add(metadata);
        }
      }
    }

    // Sort by last modified, most recent first
    conversations.sort((a, b) {
      final aTime = a.lastModified ?? a.timestamp ?? DateTime(1970);
      final bTime = b.lastModified ?? b.timestamp ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  /// List all unique projects that have conversations.
  Future<List<String>> listProjects() async {
    final conversations = await discoverAllConversations();
    final projects = conversations.map((c) => c.projectPath).toSet().toList();
    projects.sort();
    return projects;
  }

  /// List conversations for a specific project.
  Future<List<ConversationMetadata>> listConversationsForProject(
    String projectPath,
  ) async {
    final conversations = await discoverAllConversations();
    return conversations
        .where((c) => c.projectPath == projectPath)
        .toList();
  }

  /// Group conversations by project.
  Future<Map<String, List<ConversationMetadata>>> groupByProject() async {
    final conversations = await discoverAllConversations();
    final grouped = <String, List<ConversationMetadata>>{};

    for (final conv in conversations) {
      grouped.putIfAbsent(conv.projectPath, () => []).add(conv);
    }

    return grouped;
  }

  /// Load metadata from history.jsonl for enriching conversation info.
  Future<Map<String, ConversationMetadata>> _loadHistoryMetadata() async {
    final historyFile = File('$claudeDir/history.jsonl');
    if (!await historyFile.exists()) {
      return {};
    }

    final metadata = <String, ConversationMetadata>{};
    final lines = await historyFile.readAsLines();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final entry = ConversationMetadata.fromHistoryEntry(json);
        if (entry.sessionId.isNotEmpty) {
          // Use session + project as key since same session could be in different projects
          final key = '${entry.sessionId}:${entry.encodedProjectPath}';
          // Keep the most recent entry for each session
          if (!metadata.containsKey(key) ||
              (entry.timestamp != null &&
                  (metadata[key]!.timestamp == null ||
                      entry.timestamp!.isAfter(metadata[key]!.timestamp!)))) {
            metadata[key] = entry;
          }
        }
      } catch (e) {
        // Skip malformed entries
        continue;
      }
    }

    return metadata;
  }
}
