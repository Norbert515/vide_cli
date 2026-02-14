import 'package:yaml/yaml.dart';

/// Represents an etiquette protocol or behavior loaded from a .md file.
///
/// Used for both etiquette protocols and behaviors - composable prompt
/// fragments that can be included by agents or teams via the `include:` field.
class EtiquetteProtocol {
  const EtiquetteProtocol({
    required this.name,
    required this.description,
    required this.filePath,
    this.content = '',
  });

  /// Unique identifier for the protocol (e.g., "handoff", "escalation")
  final String name;

  /// Human-readable description of this protocol
  final String description;

  /// Path to the source markdown file
  final String filePath;

  /// The markdown body content (the actual protocol instructions)
  final String content;

  /// Parse an etiquette protocol from markdown content with YAML frontmatter.
  factory EtiquetteProtocol.fromMarkdown(String content, String filePath) {
    final parts = _extractFrontmatter(content);
    if (parts == null) {
      throw FormatException(
        'Invalid etiquette protocol: missing YAML frontmatter in $filePath',
      );
    }

    final (frontmatterText, body) = parts;

    final YamlMap yaml;
    try {
      yaml = loadYaml(frontmatterText) as YamlMap;
    } catch (e) {
      throw FormatException('Invalid YAML frontmatter in $filePath: $e');
    }

    final name = yaml['name'] as String?;
    final description = yaml['description'] as String? ?? '';

    if (name == null || name.isEmpty) {
      throw FormatException('Missing required field "name" in $filePath');
    }

    return EtiquetteProtocol(
      name: name,
      description: description,
      filePath: filePath,
      content: body.trim(),
    );
  }

  @override
  String toString() {
    return 'EtiquetteProtocol(name: $name)';
  }
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
