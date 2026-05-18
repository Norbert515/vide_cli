import 'package:yaml/yaml.dart';

/// Represents an agent personality loaded from a .md file.
///
/// This extends the basic Claude Code agent format with team framework fields:
/// - Included protocols
class AgentPersonality {
  const AgentPersonality({
    required this.name,
    required this.description,
    required this.filePath,
    this.displayName,
    this.shortDescription,
    this.team,
    this.tools = const [],
    this.disallowedTools = const [],
    this.mcpServers = const [],
    this.harness,
    this.allHarnessConfigs = const {},
    this.permissionMode,
    this.include = const [],
    this.agents = const [],
    this.extendsAgent,
    this.content = '',
  });

  /// Unique identifier for the agent (e.g., "implementer", "researcher")
  final String name;

  /// Display name shown in UI (e.g., "Bert", "Rex", "Tim")
  /// If not set, falls back to [name]
  final String? displayName;

  /// Short description shown next to name in UI (e.g., "Writes and fixes code")
  final String? shortDescription;

  /// Optional team tag this agent belongs to.
  /// If null, agent belongs to the root network (no sub-team).
  final String? team;

  /// Description of when to use this agent
  final String description;

  /// Path to the source markdown file
  final String filePath;

  /// Tools this agent can access (additive - for permission purposes)
  final List<String> tools;

  /// Tools this agent should NOT have access to (restrictive - actually removes tools)
  final List<String> disallowedTools;

  /// MCP servers this agent can access
  final List<String> mcpServers;

  /// Default harness for this agent (e.g., 'claude-code', 'codex-cli').
  /// If null, the session default harness is used.
  final String? harness;

  /// Harness-specific configuration maps, grouped by harness name.
  ///
  /// Parsed from flat-prefix YAML keys like `claude-code.model: opus`.
  /// Structure: `{'claude-code': {'model': 'opus'}, 'codex-cli': {'model': 'o3'}}`
  ///
  /// A personality can define config for multiple harnesses, allowing it
  /// to be spawned on different backends with appropriate settings.
  final Map<String, Map<String, dynamic>> allHarnessConfigs;

  /// Permission mode for this agent (acceptEdits, plan, ask, etc.)
  final String? permissionMode;

  /// Etiquette protocols/sections to include in system prompt
  final List<String> include;

  /// Sub-agent types this agent can spawn.
  /// Enables recursive team composition - an agent carries its own team
  /// definition regardless of which team it belongs to.
  final List<String> agents;

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
      throw FormatException(
        'Missing required field "description" in $filePath',
      );
    }

    // Parse harness-specific configs from flat-prefix keys (e.g., 'claude-code.model')
    final allHarnessConfigs = _parseHarnessConfigs(yaml);

    return AgentPersonality(
      name: name,
      description: description,
      filePath: filePath,
      displayName: yaml['display-name'] as String?,
      shortDescription: yaml['short-description'] as String?,
      team: yaml['team'] as String?,
      tools: _parseStringList(yaml['tools']),
      disallowedTools: _parseStringList(yaml['disallowedTools']),
      mcpServers: _parseStringList(yaml['mcpServers']),
      harness: yaml['harness'] as String?,
      allHarnessConfigs: allHarnessConfigs,
      permissionMode: yaml['permissionMode'] as String?,
      include: _parseStringList(yaml['include']),
      agents: _parseStringList(yaml['agents']),
      extendsAgent: yaml['extends'] as String?,
      content: body.trim(),
    );
  }

  /// Get the resolved harness config for a specific harness name.
  ///
  /// Returns the config map for the given harness, or an empty map if
  /// no config is defined for that harness.
  Map<String, dynamic> harnessConfigFor(String harness) {
    return allHarnessConfigs[harness] ?? const {};
  }

  /// Create a copy with fields from another agent merged in (for inheritance).
  AgentPersonality mergeWith(AgentPersonality base) {
    // Deep-merge harness configs: base first, child overrides per-key
    final mergedHarnessConfigs = <String, Map<String, dynamic>>{};
    for (final entry in base.allHarnessConfigs.entries) {
      mergedHarnessConfigs[entry.key] = Map.of(entry.value);
    }
    for (final entry in allHarnessConfigs.entries) {
      final existing = mergedHarnessConfigs[entry.key];
      if (existing != null) {
        existing.addAll(entry.value);
      } else {
        mergedHarnessConfigs[entry.key] = Map.of(entry.value);
      }
    }

    return AgentPersonality(
      name: name,
      description: description,
      filePath: filePath,
      displayName: displayName ?? base.displayName,
      shortDescription: shortDescription ?? base.shortDescription,
      team: team ?? base.team,
      tools: tools.isNotEmpty ? tools : base.tools,
      disallowedTools: disallowedTools.isNotEmpty
          ? disallowedTools
          : base.disallowedTools,
      mcpServers: mcpServers.isNotEmpty ? mcpServers : base.mcpServers,
      harness: harness ?? base.harness,
      allHarnessConfigs: mergedHarnessConfigs,
      permissionMode: permissionMode ?? base.permissionMode,
      include: [...base.include, ...include],
      agents: agents.isNotEmpty ? agents : base.agents,
      extendsAgent: null, // Already merged
      content: '${base.content}\n\n${content}',
    );
  }

  /// Get the effective display name (displayName or fallback to name)
  String get effectiveDisplayName => displayName ?? name;

  @override
  String toString() {
    return 'AgentPersonality(name: $name)';
  }
}

/// Parse harness-specific configs from flat-prefix YAML keys.
///
/// Scans all keys in the YAML map for keys containing a `.` separator.
/// Keys like `claude-code.model` are split into harness `claude-code` and
/// config key `model`, grouped into a map-of-maps.
Map<String, Map<String, dynamic>> _parseHarnessConfigs(YamlMap yaml) {
  final configs = <String, Map<String, dynamic>>{};
  for (final entry in yaml.entries) {
    final key = entry.key as String;
    final dotIndex = key.indexOf('.');
    if (dotIndex > 0 && dotIndex < key.length - 1) {
      final harnessName = key.substring(0, dotIndex);
      final configKey = key.substring(dotIndex + 1);
      configs.putIfAbsent(harnessName, () => {});
      configs[harnessName]![configKey] = entry.value;
    }
  }
  return configs;
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
