import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';

import '../generated/bundled_team_framework.dart';
import '../models/team_framework/team_framework.dart';
import '../agents/agent_configuration.dart';
import '../mcp/mcp_server_type.dart';
import '../utils/working_dir_provider.dart';

/// Provider for TeamFrameworkLoader.
///
/// This provides access to the team framework for loading team definitions,
/// agent personalities, and building agent configurations.
final teamFrameworkLoaderProvider = Provider<TeamFrameworkLoader>((ref) {
  final workingDir = ref.watch(workingDirProvider);
  return TeamFrameworkLoader(workingDirectory: workingDir);
});

/// Service for loading team framework definitions from markdown files.
///
/// Loads from multiple sources with precedence (highest first):
/// 1. Project-level: `.claude/teams/`, `.claude/roles/`, etc.
/// 2. User customizations: `~/.vide/user/`
/// 3. Vide defaults: `~/.vide/defaults/`
class TeamFrameworkLoader {
  TeamFrameworkLoader({String? workingDirectory, String? videHome})
    : _workingDirectory = workingDirectory ?? Directory.current.path,
      _videHome = videHome ?? _defaultVideHome;

  final String _workingDirectory;
  final String _videHome;

  static String get _defaultVideHome {
    final home = Platform.environment['HOME'] ?? '';
    return path.join(home, '.vide');
  }

  // Caches
  Map<String, TeamDefinition>? _teamsCache;
  Map<String, EtiquetteProtocol>? _etiquetteCache;
  Map<String, EtiquetteProtocol>? _behaviorsCache;
  Map<String, AgentPersonality>? _agentsCache;

  /// Load all team definitions.
  /// Returns a map of team name -> TeamDefinition.
  Future<Map<String, TeamDefinition>> loadTeams() async {
    if (_teamsCache != null) return _teamsCache!;

    _teamsCache = await _loadDefinitions<TeamDefinition>(
      subdir: 'teams',
      parser: TeamDefinition.fromMarkdown,
      getName: (t) => t.name,
    );
    return _teamsCache!;
  }

  /// Load all etiquette protocols.
  Future<Map<String, EtiquetteProtocol>> loadEtiquette() async {
    if (_etiquetteCache != null) return _etiquetteCache!;

    _etiquetteCache = await _loadDefinitions<EtiquetteProtocol>(
      subdir: 'etiquette',
      parser: EtiquetteProtocol.fromMarkdown,
      getName: (e) => e.name,
    );
    return _etiquetteCache!;
  }

  /// Load all behavior includes.
  Future<Map<String, EtiquetteProtocol>> loadBehaviors() async {
    if (_behaviorsCache != null) return _behaviorsCache!;

    _behaviorsCache = await _loadDefinitions<EtiquetteProtocol>(
      subdir: 'behaviors',
      parser: EtiquetteProtocol.fromMarkdown,
      getName: (b) => b.name,
    );
    return _behaviorsCache!;
  }

  /// Load all agent personalities.
  Future<Map<String, AgentPersonality>> loadAgents() async {
    if (_agentsCache != null) return _agentsCache!;

    _agentsCache = await _loadDefinitions<AgentPersonality>(
      subdir: 'agents',
      parser: AgentPersonality.fromMarkdown,
      getName: (a) => a.name,
    );

    // Resolve inheritance (extends)
    _agentsCache = _resolveAgentInheritance(_agentsCache!);

    return _agentsCache!;
  }

  /// Get a specific team by name.
  Future<TeamDefinition?> getTeam(String name) async {
    final teams = await loadTeams();
    return teams[name];
  }

  /// Get a specific etiquette protocol by name.
  Future<EtiquetteProtocol?> getEtiquette(String name) async {
    final etiquette = await loadEtiquette();
    return etiquette[name];
  }

  /// Get a specific behavior by name.
  Future<EtiquetteProtocol?> getBehavior(String name) async {
    final behaviors = await loadBehaviors();
    return behaviors[name];
  }

  /// Get a specific agent personality by name.
  Future<AgentPersonality?> getAgent(String name) async {
    final agents = await loadAgents();
    return agents[name];
  }

  /// Find the best matching team for a task description.
  Future<TeamDefinition?> findBestTeam(String taskDescription) async {
    final teams = await loadTeams();
    if (teams.isEmpty) return null;

    TeamDefinition? bestTeam;
    int bestScore = 0;

    for (final team in teams.values) {
      final score = team.matchScore(taskDescription);
      if (score > bestScore) {
        bestScore = score;
        bestTeam = team;
      }
    }

    // If no triggers matched, return default team
    if (bestTeam == null || bestScore == 0) {
      return teams['enterprise'] ?? teams.values.first;
    }

    return bestTeam;
  }

  /// Build the complete system prompt for an agent personality.
  ///
  /// Resolves includes from both the team (if provided) and the agent,
  /// deduplicating any overlapping include paths. Team includes come first.
  Future<String> buildAgentPrompt(
    AgentPersonality agent, {
    List<String> teamIncludes = const [],
  }) async {
    final parts = <String>[];

    // Merge team and agent includes, deduplicating (team first)
    final allIncludes = <String>[...teamIncludes];
    for (final inc in agent.include) {
      if (!allIncludes.contains(inc)) {
        allIncludes.add(inc);
      }
    }

    // Resolve all includes
    for (final includePath in allIncludes) {
      final protocol = await _resolveInclude(includePath);
      if (protocol != null) {
        parts.add(protocol);
      }
    }

    // Add agent's own content
    parts.add(agent.content);

    return parts.join('\n\n');
  }

  /// Build a complete AgentConfiguration from a team framework agent personality.
  ///
  /// This loads the agent definition, builds the complete prompt with includes,
  /// parses MCP servers and tools, and returns a ready-to-use AgentConfiguration.
  ///
  /// [agentName] - The name of the agent personality to load
  /// [teamName] - Optional team name to inject available roles context
  ///
  /// Returns null if the agent is not found, with a warning logged.
  Future<AgentConfiguration?> buildAgentConfiguration(
    String agentName, {
    String? teamName,
  }) async {
    final agent = await getAgent(agentName);
    if (agent == null) {
      print('Warning: Agent "$agentName" not found in team framework');
      return null;
    }

    // Load team if specified (used for includes and available agents)
    TeamDefinition? team;
    if (teamName != null) {
      team = await getTeam(teamName);
    }

    // Build the complete system prompt with team + agent includes
    var systemPrompt = await buildAgentPrompt(
      agent,
      teamIncludes: team?.include ?? const [],
    );

    // If agent has vide-agent MCP, inject available agent types.
    // Agent-level agents take precedence over team-level agents.
    if (agent.mcpServers.any(
      (s) => s.toLowerCase() == 'vide-agent' || s.toLowerCase() == 'agent',
    )) {
      final agentTypes = agent.agents.isNotEmpty
          ? agent.agents
          : team?.agents ?? const <String>[];
      if (agentTypes.isNotEmpty) {
        final teamName = team?.name ?? 'this';
        final availableAgents = _buildAvailableAgentsSection(
          agentTypes,
          teamName,
        );
        systemPrompt = '$availableAgents\n\n$systemPrompt';
      }
    }

    // Parse MCP servers from the agent personality
    final mcpServers = _parseMcpServers(agent.mcpServers);

    // Use tools from the agent personality if available
    final allowedTools = agent.tools.isNotEmpty ? agent.tools : null;

    // Merge disallowedTools from team and agent (team-level applies to all agents)
    final mergedDisallowedTools = <String>{
      ...?team?.disallowedTools,
      ...agent.disallowedTools,
    }.toList();
    final disallowedTools =
        mergedDisallowedTools.isNotEmpty ? mergedDisallowedTools : null;

    // Build the AgentConfiguration
    return AgentConfiguration(
      name: agent.name,
      description: agent.description,
      systemPrompt: systemPrompt,
      mcpServers: mcpServers.isNotEmpty ? mcpServers : null,
      allowedTools: allowedTools,
      disallowedTools: disallowedTools,
      model: agent.model,
      permissionMode: agent.permissionMode,
    );
  }

  /// Parse MCP server names to McpServerType enum values.
  List<McpServerType> _parseMcpServers(List<String> serverNames) {
    final servers = <McpServerType>[];

    for (final name in serverNames) {
      final normalized = name.trim().toLowerCase();
      try {
        final serverType = switch (normalized) {
          'vide-git' || 'git' => McpServerType.git,
          'vide-agent' || 'agent' => McpServerType.agent,
          'vide-task-management' ||
          'task-management' ||
          'task_management' => McpServerType.taskManagement,
          'flutter-runtime' || 'flutterruntime' => McpServerType.flutterRuntime,
          'vide-knowledge' || 'knowledge' => McpServerType.knowledge,
          _ => null,
        };

        if (serverType != null) {
          servers.add(serverType);
        } else {
          print('Warning: Unknown MCP server type "$name"');
        }
      } catch (e) {
        print('Error parsing MCP server "$name": $e');
      }
    }

    return servers;
  }

  /// Build the available agents section for injection into agent prompts.
  ///
  /// This tells the agent what agent types they can spawn.
  /// [agentTypes] is the list of agent type names (from agent or team).
  /// [teamName] is the team name for context.
  String _buildAvailableAgentsSection(
    List<String> agentTypes,
    String teamName,
  ) {
    final agentsList = agentTypes.map((a) => '- `$a`').join('\n');

    return '''## Available Agent Types

When using \`spawnAgent\`, you MUST use one of these agent type names from the "$teamName" team:

$agentsList

**IMPORTANT**: Only use the exact agent type names listed above. Other agent types will fail.''';
  }

  /// Resolve an include path to content.
  /// Supports paths like "etiquette/handoff" or "behaviors/qa-review-cycle"
  Future<String?> _resolveInclude(String includePath) async {
    final parts = includePath.split('/');
    if (parts.length != 2) return null;

    final type = parts[0];
    final name = parts[1];

    switch (type) {
      case 'etiquette':
        final protocol = await getEtiquette(name);
        return protocol?.content;
      case 'behaviors':
        final behavior = await getBehavior(name);
        return behavior?.content;
      default:
        return null;
    }
  }

  /// Resolve agent inheritance (extends field).
  Map<String, AgentPersonality> _resolveAgentInheritance(
    Map<String, AgentPersonality> agents,
  ) {
    final resolved = <String, AgentPersonality>{};

    for (final agent in agents.values) {
      if (agent.extendsAgent == null) {
        resolved[agent.name] = agent;
      } else {
        final base = agents[agent.extendsAgent];
        if (base != null) {
          resolved[agent.name] = agent.mergeWith(base);
        } else {
          // Base not found, use as-is
          resolved[agent.name] = agent;
        }
      }
    }

    return resolved;
  }

  /// Load definitions of type T from all sources.
  Future<Map<String, T>> _loadDefinitions<T>({
    required String subdir,
    required T Function(String content, String filePath) parser,
    required String Function(T) getName,
  }) async {
    final results = <String, T>{};

    // Load in reverse precedence order (so higher precedence overwrites)
    // 1. Bundled defaults (lowest precedence)
    _loadFromBundled(subdir, parser, getName, results);

    // 2. User customizations
    await _loadFromDirectory(
      path.join(_videHome, 'user', subdir),
      parser,
      getName,
      results,
      'user',
    );

    // 3. Project-level (highest precedence)
    await _loadFromDirectory(
      path.join(_workingDirectory, '.claude', subdir),
      parser,
      getName,
      results,
      'project',
    );

    return results;
  }

  /// Load definitions from bundled in-memory constants.
  void _loadFromBundled<T>(
    String subdir,
    T Function(String content, String filePath) parser,
    String Function(T) getName,
    Map<String, T> results,
  ) {
    final bundledMap = switch (subdir) {
      'teams' => bundledTeams,
      'agents' => bundledAgents,
      'etiquette' => bundledEtiquette,
      'behaviors' => bundledBehaviors,
      _ => <String, String>{},
    };

    for (final entry in bundledMap.entries) {
      try {
        final definition = parser(entry.value, 'bundled://${entry.key}.md');
        final name = getName(definition);
        results[name] = definition;
      } catch (e) {
        print('Error loading bundled ${entry.key}: $e');
      }
    }
  }

  /// Load definitions from a single directory.
  Future<void> _loadFromDirectory<T>(
    String dirPath,
    T Function(String content, String filePath) parser,
    String Function(T) getName,
    Map<String, T> results,
    String source,
  ) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    try {
      final files = dir.listSync().whereType<File>().where(
        (f) => path.extension(f.path) == '.md',
      );

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final definition = parser(content, file.path);
          final name = getName(definition);
          results[name] = definition;
        } catch (e) {
          // Log but continue loading other files
          print('Error loading $source ${path.basename(file.path)}: $e');
        }
      }
    } catch (e) {
      print('Error scanning directory $dirPath: $e');
    }
  }

  /// Clear all caches, forcing reload on next access.
  void clearCache() {
    _teamsCache = null;
    _etiquetteCache = null;
    _behaviorsCache = null;
    _agentsCache = null;
  }
}
