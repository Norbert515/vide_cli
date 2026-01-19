import 'dart:io';
import 'package:path/path.dart' as path;

import '../../models/team_framework/team_framework.dart';
import '../agents/agent_configuration.dart';
import '../mcp/mcp_server_type.dart';

/// Service for loading team framework definitions from markdown files.
///
/// Loads from multiple sources with precedence (highest first):
/// 1. Project-level: `.claude/teams/`, `.claude/roles/`, etc.
/// 2. User customizations: `~/.vide/user/`
/// 3. Vide defaults: `~/.vide/defaults/`
class TeamFrameworkLoader {
  TeamFrameworkLoader({
    String? workingDirectory,
    String? videHome,
  })  : _workingDirectory = workingDirectory ?? Directory.current.path,
        _videHome = videHome ?? _defaultVideHome;

  final String _workingDirectory;
  final String _videHome;

  static String get _defaultVideHome {
    final home = Platform.environment['HOME'] ?? '';
    return path.join(home, '.vide');
  }

  // Caches
  Map<String, TeamDefinition>? _teamsCache;
  Map<String, RoleDefinition>? _rolesCache;
  Map<String, EtiquetteProtocol>? _etiquetteCache;
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

  /// Load all role definitions.
  Future<Map<String, RoleDefinition>> loadRoles() async {
    if (_rolesCache != null) return _rolesCache!;

    _rolesCache = await _loadDefinitions<RoleDefinition>(
      subdir: 'roles',
      parser: RoleDefinition.fromMarkdown,
      getName: (r) => r.name,
    );
    return _rolesCache!;
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

  /// Get a specific role by name.
  Future<RoleDefinition?> getRole(String name) async {
    final roles = await loadRoles();
    return roles[name];
  }

  /// Get a specific etiquette protocol by name.
  Future<EtiquetteProtocol?> getEtiquette(String name) async {
    final etiquette = await loadEtiquette();
    return etiquette[name];
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
      return teams['balanced'] ?? teams.values.first;
    }

    return bestTeam;
  }

  /// Build the complete system prompt for an agent personality.
  /// Includes the agent's content plus any included etiquette protocols.
  Future<String> buildAgentPrompt(AgentPersonality agent) async {
    final parts = <String>[];

    // Add included etiquette protocols
    for (final includePath in agent.include) {
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
  /// Returns null if the agent is not found, with a warning logged.
  Future<AgentConfiguration?> buildAgentConfiguration(String agentName) async {
    final agent = await getAgent(agentName);
    if (agent == null) {
      print('Warning: Agent "$agentName" not found in team framework');
      return null;
    }

    // Build the complete system prompt with includes
    final systemPrompt = await buildAgentPrompt(agent);

    // Parse MCP servers from the agent personality
    final mcpServers = _parseMcpServers(agent.mcpServers);

    // Use tools from the agent personality if available
    final allowedTools = agent.tools.isNotEmpty ? agent.tools : null;

    // Build the AgentConfiguration
    return AgentConfiguration(
      name: agent.name,
      description: agent.description,
      systemPrompt: systemPrompt,
      mcpServers: mcpServers.isNotEmpty ? mcpServers : null,
      allowedTools: allowedTools,
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
          'vide-task-management' || 'task-management' || 'task_management' =>
            McpServerType.taskManagement,
          'flutter-runtime' || 'flutterruntime' => McpServerType.flutterRuntime,
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

  /// Resolve an include path to content.
  /// Supports paths like "etiquette/handoff" or "roles/lead"
  Future<String?> _resolveInclude(String includePath) async {
    final parts = includePath.split('/');
    if (parts.length != 2) return null;

    final type = parts[0];
    final name = parts[1];

    switch (type) {
      case 'etiquette':
        final protocol = await getEtiquette(name);
        return protocol?.content;
      case 'roles':
        final role = await getRole(name);
        return role?.content;
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
    // 1. Vide defaults (lowest precedence)
    await _loadFromDirectory(
      path.join(_videHome, 'defaults', subdir),
      parser,
      getName,
      results,
      'defaults',
    );

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
    _rolesCache = null;
    _etiquetteCache = null;
    _agentsCache = null;
  }
}
