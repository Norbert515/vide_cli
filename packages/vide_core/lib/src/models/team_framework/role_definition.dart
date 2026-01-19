import 'package:yaml/yaml.dart';

/// Represents a role definition loaded from a .md file.
///
/// Roles define responsibilities (the "what"), not personalities (the "who").
/// Based on RACI model: Responsible, Accountable, Consulted, Informed.
class RoleDefinition {
  const RoleDefinition({
    required this.name,
    required this.description,
    required this.filePath,
    this.raci = RaciType.responsible,
    this.responsibilities = const [],
    this.canDo = const [],
    this.cannotDo = const [],
    this.mcpServers = const [],
    this.content = '',
  });

  /// Unique identifier for the role (e.g., "lead", "implementer")
  final String name;

  /// Human-readable description of this role
  final String description;

  /// Path to the source markdown file
  final String filePath;

  /// RACI designation for this role
  final RaciType raci;

  /// List of responsibilities this role has
  final List<String> responsibilities;

  /// Actions this role CAN perform
  final List<String> canDo;

  /// Actions this role CANNOT perform
  final List<String> cannotDo;

  /// MCP servers this role typically needs access to
  final List<String> mcpServers;

  /// The markdown body content (detailed role description)
  final String content;

  /// Parse a role definition from markdown content with YAML frontmatter.
  factory RoleDefinition.fromMarkdown(String content, String filePath) {
    final parts = _extractFrontmatter(content);
    if (parts == null) {
      throw FormatException(
        'Invalid role definition: missing YAML frontmatter in $filePath',
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
    final description = yaml['description'] as String?;

    if (name == null || name.isEmpty) {
      throw FormatException('Missing required field "name" in $filePath');
    }
    if (description == null || description.isEmpty) {
      throw FormatException('Missing required field "description" in $filePath');
    }

    // Parse RACI type
    final raciString = yaml['raci'] as String?;
    final raci = RaciType.fromString(raciString);

    // Parse lists
    final responsibilities = _parseStringList(yaml['responsibilities']);
    final canDo = _parseStringList(yaml['can']);
    final cannotDo = _parseStringList(yaml['cannot']);
    final mcpServers = _parseStringList(yaml['mcpServers']);

    return RoleDefinition(
      name: name,
      description: description,
      filePath: filePath,
      raci: raci,
      responsibilities: responsibilities,
      canDo: canDo,
      cannotDo: cannotDo,
      mcpServers: mcpServers,
      content: body.trim(),
    );
  }

  @override
  String toString() {
    return 'RoleDefinition(name: $name, raci: ${raci.name})';
  }
}

/// RACI model designations
enum RaciType {
  /// Responsible: Does the work
  responsible,

  /// Accountable: Ultimately answerable for completion
  accountable,

  /// Consulted: Provides input and feedback
  consulted,

  /// Informed: Kept in the loop
  informed;

  static RaciType fromString(String? value) {
    return RaciType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RaciType.responsible,
    );
  }
}

/// Parse a YAML field as a list of strings.
List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is YamlList) {
    return value.cast<String>().toList();
  }
  if (value is String) {
    return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return [];
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
