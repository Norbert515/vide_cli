import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Service for managing the knowledge base stored in `.claude/knowledge/`.
///
/// The knowledge base is a hierarchical system of markdown documents with
/// YAML frontmatter containing metadata like title, type, tags, etc.
///
/// Directory structure:
/// ```
/// .claude/knowledge/
/// ├── global/           # Cross-session knowledge
/// │   ├── decisions/    # ADRs, architectural decisions
/// │   ├── patterns/     # Discovered patterns
/// │   └── findings/     # Facts and discoveries
/// ├── teams/
/// │   └── {team-name}/  # Team-scoped knowledge
/// └── agents/
///     └── {agent-name}/ # Agent-scoped knowledge
/// ```
class KnowledgeService {
  KnowledgeService({required this.projectPath});

  final String projectPath;

  /// Get the root knowledge directory path
  String get knowledgeRoot => path.join(projectPath, '.claude', 'knowledge');

  /// Ensure the knowledge directory structure exists
  Future<void> ensureDirectoryStructure() async {
    final dirs = [
      path.join(knowledgeRoot, 'global', 'decisions'),
      path.join(knowledgeRoot, 'global', 'patterns'),
      path.join(knowledgeRoot, 'global', 'findings'),
    ];

    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
  }

  /// Get all knowledge documents (shallow - just metadata)
  Future<List<KnowledgeDocument>> getIndex({String? scope}) async {
    final documents = <KnowledgeDocument>[];
    final rootDir = Directory(_getScopePath(scope));

    if (!await rootDir.exists()) {
      return documents;
    }

    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final doc = await _parseDocument(entity.path, shallow: true);
          if (doc != null) {
            documents.add(doc);
          }
        } catch (e) {
          // Skip files that can't be parsed
        }
      }
    }

    return documents;
  }

  /// Get a document summary (metadata + first paragraph)
  Future<KnowledgeDocument?> getSummary(String docPath) async {
    final fullPath = path.join(knowledgeRoot, docPath);
    return _parseDocument(fullPath, shallow: false, summaryOnly: true);
  }

  /// Read the full content of a knowledge document
  Future<KnowledgeDocument?> readDocument(String docPath) async {
    final fullPath = path.join(knowledgeRoot, docPath);
    return _parseDocument(fullPath, shallow: false, summaryOnly: false);
  }

  /// Write a knowledge document
  ///
  /// [docPath] - Relative path within knowledge root (e.g., "global/decisions/use-jwt.md")
  /// [title] - Document title
  /// [type] - Document type (decision, finding, pattern, etc.)
  /// [content] - Markdown content body
  /// [tags] - Optional list of tags
  /// [author] - Optional author name
  /// [references] - Optional list of code references
  Future<void> writeDocument({
    required String docPath,
    required String title,
    required String type,
    required String content,
    List<String>? tags,
    String? author,
    List<String>? references,
  }) async {
    final fullPath = path.join(knowledgeRoot, docPath);
    final dir = Directory(path.dirname(fullPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final frontmatter = StringBuffer()
      ..writeln('---')
      ..writeln('title: $title')
      ..writeln('type: $type')
      ..writeln('created: ${DateTime.now().toIso8601String()}')
      ..writeln('status: active');

    if (author != null) {
      frontmatter.writeln('author: $author');
    }

    if (tags != null && tags.isNotEmpty) {
      frontmatter.writeln('tags: [${tags.join(', ')}]');
    }

    if (references != null && references.isNotEmpty) {
      frontmatter.writeln('references:');
      for (final ref in references) {
        frontmatter.writeln('  - "$ref"');
      }
    }

    frontmatter.writeln('---');

    final fullContent = '${frontmatter.toString()}\n# $title\n\n$content';
    await File(fullPath).writeAsString(fullContent);
  }

  /// Search knowledge documents by keyword
  ///
  /// Uses simple keyword matching. Returns documents sorted by relevance.
  Future<List<KnowledgeSearchResult>> searchDocuments(
    String query, {
    String? scope,
    int limit = 10,
  }) async {
    final results = <KnowledgeSearchResult>[];
    final queryTerms = query.toLowerCase().split(RegExp(r'\s+'));
    final rootDir = Directory(_getScopePath(scope));

    if (!await rootDir.exists()) {
      return results;
    }

    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final content = await entity.readAsString();
          final doc = await _parseDocument(entity.path, shallow: false);
          if (doc == null) continue;

          // Calculate relevance score
          final lowerContent = content.toLowerCase();
          var score = 0;
          String? snippet;

          for (final term in queryTerms) {
            if (doc.title.toLowerCase().contains(term)) {
              score += 10; // Title match is most important
            }
            if (doc.tags.any((t) => t.toLowerCase().contains(term))) {
              score += 5; // Tag match
            }
            if (lowerContent.contains(term)) {
              score += 1; // Content match
              // Extract snippet around first match
              if (snippet == null) {
                final index = lowerContent.indexOf(term);
                final start = (index - 50).clamp(0, content.length);
                final end = (index + 100).clamp(0, content.length);
                snippet = '...${content.substring(start, end)}...';
              }
            }
          }

          if (score > 0) {
            results.add(
              KnowledgeSearchResult(
                document: doc,
                score: score,
                snippet: snippet,
              ),
            );
          }
        } catch (e) {
          // Skip files that can't be parsed
        }
      }
    }

    // Sort by score descending, take top N
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// List documents filtered by type and/or tags
  Future<List<KnowledgeDocument>> listDocuments({
    String? scope,
    String? type,
    List<String>? tags,
  }) async {
    final allDocs = await getIndex(scope: scope);
    return allDocs.where((doc) {
      if (type != null && doc.type != type) return false;
      if (tags != null && tags.isNotEmpty) {
        if (!tags.any((tag) => doc.tags.contains(tag))) return false;
      }
      return true;
    }).toList();
  }

  /// Get the path for a given scope
  String _getScopePath(String? scope) {
    if (scope == null) {
      return knowledgeRoot;
    }
    if (scope.startsWith('team:')) {
      return path.join(knowledgeRoot, 'teams', scope.substring(5));
    }
    if (scope.startsWith('agent:')) {
      return path.join(knowledgeRoot, 'agents', scope.substring(6));
    }
    if (scope == 'global') {
      return path.join(knowledgeRoot, 'global');
    }
    return knowledgeRoot;
  }

  /// Parse a knowledge document from a file path
  Future<KnowledgeDocument?> _parseDocument(
    String filePath, {
    required bool shallow,
    bool summaryOnly = false,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final parts = _extractFrontmatter(content);
    if (parts == null) return null;

    final (frontmatterText, body) = parts;
    final yaml = loadYaml(frontmatterText) as YamlMap?;
    if (yaml == null) return null;

    final relativePath = path.relative(filePath, from: knowledgeRoot);

    // Extract summary (first non-empty paragraph after title)
    String? summary;
    if (!shallow) {
      final lines = body.split('\n');
      final summaryLines = <String>[];
      var foundContent = false;
      for (final line in lines) {
        if (line.startsWith('#')) continue; // Skip titles
        if (line.trim().isEmpty) {
          if (foundContent) break; // End of first paragraph
          continue;
        }
        foundContent = true;
        summaryLines.add(line);
      }
      if (summaryLines.isNotEmpty) {
        summary = summaryLines.join(' ').trim();
        if (summary.length > 200) {
          summary = '${summary.substring(0, 200)}...';
        }
      }
    }

    return KnowledgeDocument(
      path: relativePath,
      title:
          yaml['title'] as String? ?? path.basenameWithoutExtension(filePath),
      type: yaml['type'] as String? ?? 'unknown',
      status: yaml['status'] as String? ?? 'active',
      tags: _parseStringList(yaml['tags']),
      author: yaml['author'] as String?,
      created: yaml['created'] != null
          ? DateTime.tryParse(yaml['created'] as String)
          : null,
      references: _parseStringList(yaml['references']),
      summary: summary,
      content: shallow || summaryOnly ? null : body.trim(),
    );
  }

  /// Extract YAML frontmatter and markdown body from content.
  (String, String)? _extractFrontmatter(String content) {
    final pattern = RegExp(
      r'^---\s*\n(.*?)\n---\s*\n(.*)$',
      dotAll: true,
      multiLine: true,
    );

    final match = pattern.firstMatch(content);
    if (match == null) return null;

    return (match.group(1) ?? '', match.group(2) ?? '');
  }

  /// Parse a YAML field as a list of strings.
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is YamlList) {
      return value.cast<String>().toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}

/// A knowledge document with metadata and optional content.
class KnowledgeDocument {
  const KnowledgeDocument({
    required this.path,
    required this.title,
    required this.type,
    required this.status,
    this.tags = const [],
    this.author,
    this.created,
    this.references = const [],
    this.summary,
    this.content,
  });

  /// Relative path within knowledge root
  final String path;

  /// Document title
  final String title;

  /// Document type (decision, finding, pattern, etc.)
  final String type;

  /// Document status (active, archived, superseded)
  final String status;

  /// Tags for categorization
  final List<String> tags;

  /// Author name
  final String? author;

  /// Creation timestamp
  final DateTime? created;

  /// Code references
  final List<String> references;

  /// Summary (first paragraph)
  final String? summary;

  /// Full markdown content (null for shallow queries)
  final String? content;

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'type': type,
    'status': status,
    'tags': tags,
    if (author != null) 'author': author,
    if (created != null) 'created': created!.toIso8601String(),
    if (references.isNotEmpty) 'references': references,
    if (summary != null) 'summary': summary,
    if (content != null) 'content': content,
  };
}

/// Search result with relevance score and snippet.
class KnowledgeSearchResult {
  const KnowledgeSearchResult({
    required this.document,
    required this.score,
    this.snippet,
  });

  final KnowledgeDocument document;
  final int score;
  final String? snippet;

  Map<String, dynamic> toJson() => {
    ...document.toJson(),
    'score': score,
    if (snippet != null) 'snippet': snippet,
  };
}
