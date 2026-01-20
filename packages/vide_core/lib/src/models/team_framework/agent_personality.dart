import 'package:yaml/yaml.dart';

/// Represents an agent personality loaded from a .md file.
///
/// This extends the basic Claude Code agent format with team framework fields:
/// - Archetype (personality type)
/// - Behavioral traits
/// - Things to avoid
/// - Included protocols
class AgentPersonality {
  const AgentPersonality({
    required this.name,
    required this.description,
    required this.filePath,
    this.archetype,
    this.tools = const [],
    this.disallowedTools = const [],
    this.mcpServers = const [],
    this.model,
    this.permissionMode,
    this.traits = const [],
    this.avoids = const [],
    this.include = const [],
    this.extendsAgent,
    this.content = '',
  });

  /// Unique identifier for the agent (e.g., "pragmatic-lead")
  final String name;

  /// Description of when to use this agent
  final String description;

  /// Path to the source markdown file
  final String filePath;

  /// Personality archetype (e.g., "pragmatist", "guardian", "explorer")
  final String? archetype;

  /// Tools this agent can access (additive - for permission purposes)
  final List<String> tools;

  /// Tools this agent should NOT have access to (restrictive - actually removes tools)
  final List<String> disallowedTools;

  /// MCP servers this agent can access
  final List<String> mcpServers;

  /// Model to use (sonnet, opus, haiku)
  final String? model;

  /// Permission mode for this agent (acceptEdits, plan, ask, etc.)
  final String? permissionMode;

  /// Behavioral traits this agent exhibits
  final List<String> traits;

  /// Things this agent explicitly avoids
  final List<String> avoids;

  /// Etiquette protocols/sections to include in system prompt
  final List<String> include;

  /// Name of base agent to extend
  final String? extendsAgent;

  /// The markdown body content (system prompt)
  final String content;

  /// Parse an agent personality from markdown content with YAML frontmatter.
  factory AgentPersonality.fromMarkdown(String content, String filePath) {
    final parts = _extractFrontmatter(content);
    if (parts == null) {
      throw FormatException(
        'Invalid agent personality: missing YAML frontmatter in $filePath',
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

    return AgentPersonality(
      name: name,
      description: description,
      filePath: filePath,
      archetype: yaml['archetype'] as String?,
      tools: _parseStringList(yaml['tools']),
      disallowedTools: _parseStringList(yaml['disallowedTools']),
      mcpServers: _parseStringList(yaml['mcpServers']),
      model: yaml['model'] as String?,
      permissionMode: yaml['permissionMode'] as String?,
      traits: _parseStringList(yaml['traits']),
      avoids: _parseStringList(yaml['avoids']),
      include: _parseStringList(yaml['include']),
      extendsAgent: yaml['extends'] as String?,
      content: body.trim(),
    );
  }

  /// Create a copy with fields from another agent merged in (for inheritance).
  AgentPersonality mergeWith(AgentPersonality base) {
    return AgentPersonality(
      name: name,
      description: description,
      filePath: filePath,
      archetype: archetype ?? base.archetype,
      tools: tools.isNotEmpty ? tools : base.tools,
      disallowedTools: disallowedTools.isNotEmpty ? disallowedTools : base.disallowedTools,
      mcpServers: mcpServers.isNotEmpty ? mcpServers : base.mcpServers,
      model: model ?? base.model,
      permissionMode: permissionMode ?? base.permissionMode,
      traits: [...base.traits, ...traits],
      avoids: [...base.avoids, ...avoids],
      include: [...base.include, ...include],
      extendsAgent: null, // Already merged
      content: '${base.content}\n\n${content}',
    );
  }

  @override
  String toString() {
    return 'AgentPersonality(name: $name, archetype: $archetype)';
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
