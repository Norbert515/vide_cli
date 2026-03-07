import 'agent_configuration.dart';
import '../logging/vide_logger.dart';
import '../models/agent_metadata.dart';
import '../team_framework/team_framework.dart';
import '../team_framework/team_framework_loader.dart';

/// Resolves agent configurations from the team framework.
///
/// Provides a single entry point for all team framework lookups:
/// agent configurations, team definitions, and agent personalities.
class AgentConfigResolver {
  AgentConfigResolver(
    this._teamFrameworkLoader, {
    bool Function()? getChannelViewEnabled,
  }) : _getChannelViewEnabled = getChannelViewEnabled ?? (() => true);

  final TeamFrameworkLoader _teamFrameworkLoader;
  final bool Function() _getChannelViewEnabled;

  /// Get a team definition by name.
  Future<TeamDefinition?> getTeam(String name) =>
      _teamFrameworkLoader.getTeam(name);

  /// Get an agent personality by name.
  Future<AgentPersonality?> getAgent(String name) =>
      _teamFrameworkLoader.getAgent(name);

  /// Get the appropriate AgentConfiguration for a given agent type string.
  ///
  /// [type] - The agent type (e.g., 'main', 'fork', or an agent personality name like 'solid-implementer')
  /// [teamName] - The team to use for looking up agent configurations.
  Future<AgentConfiguration> getConfigurationForType(
    String type, {
    required String teamName,
    String? harnessOverride,
  }) async {
    var effectiveTeamName = teamName;

    // Get team definition to find the agent name
    var team = await _teamFrameworkLoader.getTeam(effectiveTeamName);

    // If team not found, fall back to default 'enterprise' team
    if (team == null) {
      VideLogger.instance.warn(
        'AgentConfigResolver',
        'Team "$effectiveTeamName" not found, falling back to "enterprise"',
      );
      effectiveTeamName = 'enterprise';
      team = await _teamFrameworkLoader.getTeam(effectiveTeamName);
      if (team == null) {
        throw Exception(
          'Default team "enterprise" not found in team framework',
        );
      }
    }

    // Determine the agent personality name based on type
    final agentName = switch (type) {
      'main' => team.mainAgent,
      'fork' => team.mainAgent,
      _ => type, // The type IS the agent personality name
    };

    final config = await _teamFrameworkLoader.buildAgentConfiguration(
      agentName,
      teamName: effectiveTeamName,
      harnessOverride: harnessOverride,
      channelViewEnabled: _getChannelViewEnabled(),
    );
    if (config == null) {
      throw Exception(
        'Agent configuration not found for: $agentName (type: $type)',
      );
    }

    return config;
  }

  /// Generate a unique display name for an agent.
  ///
  /// Uses the base name from the personality, appending a number if duplicate.
  /// Example: "Bert", "Bert 2", "Bert 3"
  String generateUniqueName(
    String baseName,
    List<AgentMetadata> existingAgents,
  ) {
    final existingNames = existingAgents.map((a) => a.name).toSet();

    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    var counter = 2;
    while (existingNames.contains('$baseName $counter')) {
      counter++;
    }
    return '$baseName $counter';
  }
}
