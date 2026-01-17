import 'package:yaml/yaml.dart';

/// Represents an etiquette protocol loaded from a .md file.
///
/// Etiquette protocols define HOW agents communicate, including:
/// - Handoff formats
/// - Escalation procedures
/// - Reporting standards
/// - Messaging conventions
class EtiquetteProtocol {
  const EtiquetteProtocol({
    required this.name,
    required this.description,
    required this.filePath,
    this.appliesTo = AppliesTo.all,
    this.specificRoles = const [],
    this.content = '',
  });

  /// Unique identifier for the protocol (e.g., "handoff", "escalation")
  final String name;

  /// Human-readable description of this protocol
  final String description;

  /// Path to the source markdown file
  final String filePath;

  /// Who this protocol applies to
  final AppliesTo appliesTo;

  /// Specific roles this applies to (if appliesTo is 'specific')
  final List<String> specificRoles;

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

    // Parse applies-to
    final appliesToValue = yaml['applies-to'] as String?;
    AppliesTo appliesTo;
    List<String> specificRoles = [];

    if (appliesToValue == null || appliesToValue == 'all') {
      appliesTo = AppliesTo.all;
    } else if (appliesToValue.contains(',')) {
      // List of specific roles
      appliesTo = AppliesTo.specific;
      specificRoles = appliesToValue
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      appliesTo = AppliesTo.specific;
      specificRoles = [appliesToValue];
    }

    return EtiquetteProtocol(
      name: name,
      description: description,
      filePath: filePath,
      appliesTo: appliesTo,
      specificRoles: specificRoles,
      content: body.trim(),
    );
  }

  /// Check if this protocol applies to the given role.
  bool appliesToRole(String roleName) {
    if (appliesTo == AppliesTo.all) return true;
    return specificRoles.contains(roleName);
  }

  @override
  String toString() {
    return 'EtiquetteProtocol(name: $name, appliesTo: ${appliesTo.name})';
  }
}

/// Who the protocol applies to
enum AppliesTo {
  /// Applies to all roles/agents
  all,

  /// Applies to specific roles only
  specific,
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
