import 'dart:io';
import 'package:path/path.dart' as path;
import 'user_defined_agent.dart';

/// Service for loading user-defined agents from markdown files.
///
/// Scans `.claude/agents/` directories for `*.md` files and parses them
/// into [UserDefinedAgent] objects following the Claude specification.
class AgentLoader {
  /// Cache of loaded agents by name
  final Map<String, UserDefinedAgent> _cache = {};

  /// Whether agents have been loaded
  bool _isLoaded = false;

  /// Loads all custom agents from `.claude/agents/` directories.
  ///
  /// Searches in order:
  /// 1. Project-level: `.claude/agents/` relative to current working directory
  /// 2. User-level: `~/.claude/agents/` (optional, commented out for now)
  ///
  /// Returns a map of agent name -> UserDefinedAgent.
  /// Caches results for subsequent calls.
  Future<Map<String, UserDefinedAgent>> loadAgents() async {
    if (_isLoaded) {
      return Map.unmodifiable(_cache);
    }

    _cache.clear();

    // Load project-level agents
    final projectAgentsDir = Directory('.claude/agents');
    if (await projectAgentsDir.exists()) {
      await _loadAgentsFromDirectory(projectAgentsDir, 'project');
    }

    // Optionally load user-level agents from ~/.claude/agents/
    // Uncomment to enable user-level agents:
    // final userAgentsDir = Directory(
    //   path.join(Platform.environment['HOME'] ?? '', '.claude/agents'),
    // );
    // if (await userAgentsDir.exists()) {
    //   await _loadAgentsFromDirectory(userAgentsDir, 'user');
    // }

    _isLoaded = true;
    return Map.unmodifiable(_cache);
  }

  /// Reloads agents from disk, clearing the cache.
  Future<Map<String, UserDefinedAgent>> reloadAgents() async {
    _isLoaded = false;
    return loadAgents();
  }

  /// Loads agents from a specific directory.
  Future<void> _loadAgentsFromDirectory(Directory dir, String source) async {
    try {
      final files = dir.listSync().whereType<File>().where(
        (f) => path.extension(f.path) == '.md',
      );

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final agent = UserDefinedAgent.fromMarkdown(content, file.path);

          // Check for duplicate agent names
          if (_cache.containsKey(agent.name)) {
            print(
              'Warning: Duplicate agent name "${agent.name}" found in '
              '${file.path}. Skipping (already loaded from ${_cache[agent.name]?.filePath}).',
            );
            continue;
          }

          _cache[agent.name] = agent;
          print('Loaded $source agent: ${agent.name} from ${file.path}');
        } catch (e) {
          print('Error loading agent from ${file.path}: $e');
          // Continue loading other agents
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  /// Gets a specific agent by name.
  ///
  /// Returns null if the agent is not found.
  /// Ensures agents are loaded before lookup.
  Future<UserDefinedAgent?> getAgent(String name) async {
    await loadAgents();
    return _cache[name];
  }

  /// Gets the count of loaded custom agents.
  Future<int> getAgentCount() async {
    await loadAgents();
    return _cache.length;
  }

  /// Gets all loaded agent names.
  Future<List<String>> getAgentNames() async {
    await loadAgents();
    return _cache.keys.toList()..sort();
  }

  /// Checks if a specific agent exists.
  Future<bool> hasAgent(String name) async {
    await loadAgents();
    return _cache.containsKey(name);
  }

  /// Clears the agent cache.
  void clearCache() {
    _cache.clear();
    _isLoaded = false;
  }
}

/// Global singleton instance of AgentLoader.
final agentLoader = AgentLoader();
