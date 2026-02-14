import 'agent_configuration.dart';
import '../models/agent_metadata.dart';
import '../team_framework/team_framework_loader.dart';

/// Resolves agent configurations from the team framework.
///
/// Handles mapping agent types to their personality names and loading
/// the appropriate configuration, with fallback to the default team.
class AgentConfigResolver {
  AgentConfigResolver(this._teamFrameworkLoader);

  final TeamFrameworkLoader _teamFrameworkLoader;

  /// Get the appropriate AgentConfiguration for a given agent type string.
  ///
  /// [type] - The agent type (e.g., 'main', 'fork', or an agent personality name like 'solid-implementer')
  /// [teamName] - The team to use for looking up agent configurations.
  Future<AgentConfiguration> getConfigurationForType(
    String type, {
    required String teamName,
  }) async {
    var effectiveTeamName = teamName;

    // Get team definition to find the agent name
    var team = await _teamFrameworkLoader.getTeam(effectiveTeamName);

    // If team not found, fall back to default 'enterprise' team
    if (team == null) {
      print(
        '[AgentConfigResolver] Team "$effectiveTeamName" not found, falling back to "enterprise"',
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
