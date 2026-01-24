import 'package:riverpod/riverpod.dart';
import '../models/agent_id.dart';
import '../models/agent_network.dart';
import '../models/team_framework/team_definition.dart';
import 'agent_network_manager.dart';
import 'team_framework_loader.dart';

/// Lifecycle trigger points that can spawn agents.
///
/// These are the only trigger points available - they're defined in code,
/// not user-configurable. Team configurations decide which agents to spawn
/// for each trigger.
enum TriggerPoint {
  /// When a new session begins
  onSessionStart,

  /// When session ends (user explicitly ends or closes)
  onSessionEnd,

  /// When the main task is marked complete (via setTaskName or goal completion)
  onTaskComplete,

  /// When all spawned agents become idle
  onAllAgentsIdle,
}

/// Context provided to triggered agents.
class TriggerContext {
  const TriggerContext({
    required this.triggerPoint,
    required this.network,
    required this.teamName,
    this.taskName,
    this.filesChanged,
  });

  final TriggerPoint triggerPoint;
  final AgentNetwork network;
  final String teamName;
  final String? taskName;
  final List<String>? filesChanged;

  /// Build the prompt context for a triggered agent.
  String buildContextSection() {
    final buffer = StringBuffer();

    buffer.writeln('## Trigger Context');
    buffer.writeln();
    buffer.writeln('You were spawned by trigger: `${triggerPoint.name}`');
    buffer.writeln();
    buffer.writeln('### Session');
    buffer.writeln('- **ID**: ${network.id}');
    buffer.writeln('- **Goal**: ${network.goal}');
    buffer.writeln('- **Team**: $teamName');
    buffer.writeln();

    buffer.writeln('### Agents in Session');
    for (final agent in network.agents) {
      final desc = agent.shortDescription != null ? ' - ${agent.shortDescription}' : '';
      buffer.writeln('- **${agent.name}** (${agent.type})$desc');
    }
    buffer.writeln();

    if (taskName != null) {
      buffer.writeln('### Task');
      buffer.writeln('- **Name**: $taskName');
      if (filesChanged != null && filesChanged!.isNotEmpty) {
        buffer.writeln('- **Files changed**:');
        for (final file in filesChanged!) {
          buffer.writeln('  - `$file`');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// Provider for TriggerService.
final triggerServiceProvider = Provider<TriggerService>((ref) {
  return TriggerService(ref: ref);
});

/// Service for firing lifecycle triggers that spawn agents.
///
/// Triggers are configured in team markdown files. When a trigger fires,
/// this service checks if the current team has that trigger enabled,
/// and if so, spawns the configured agent.
class TriggerService {
  TriggerService({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Track when each trigger point was last fired to prevent duplicate firing.
  /// Key is "${networkId}:${triggerPoint.name}", value is when it was fired.
  final Map<String, DateTime> _lastFired = {};

  /// Cooldown period to prevent duplicate triggers (e.g., from both auto-sync and explicit call)
  /// For onAllAgentsIdle, use a longer cooldown to prevent spawned agents from re-triggering.
  static const _triggerCooldown = Duration(seconds: 2);
  static const _allAgentsIdleCooldown = Duration(seconds: 60);

  /// Fire a trigger point with the given context.
  ///
  /// This will:
  /// 1. Check for duplicate firing (cooldown period)
  /// 2. Look up the team's trigger configuration
  /// 3. Check if the trigger is enabled
  /// 4. Spawn the configured agent with context
  ///
  /// Returns the spawned agent ID, or null if trigger was not enabled or was recently fired.
  Future<AgentId?> fire(TriggerContext context) async {
    // Check for duplicate firing (prevents both auto-sync and explicit setAgentStatus from firing)
    final triggerKey = '${context.network.id}:${context.triggerPoint.name}';
    final lastFiredAt = _lastFired[triggerKey];
    // Use longer cooldown for onAllAgentsIdle to prevent infinite spawning loops
    final cooldown = context.triggerPoint == TriggerPoint.onAllAgentsIdle
        ? _allAgentsIdleCooldown
        : _triggerCooldown;
    if (lastFiredAt != null) {
      final elapsed = DateTime.now().difference(lastFiredAt);
      if (elapsed < cooldown) {
        print('[TriggerService] Skipping ${context.triggerPoint.name} - fired ${elapsed.inMilliseconds}ms ago (cooldown: ${cooldown.inMilliseconds}ms)');
        return null;
      }
    }

    final loader = _ref.read(teamFrameworkLoaderProvider);
    final team = await loader.getTeam(context.teamName);

    if (team == null) {
      print('[TriggerService] Team "${context.teamName}" not found, skipping trigger');
      return null;
    }

    final triggerConfig = team.lifecycleTriggers[context.triggerPoint.name];
    if (triggerConfig == null || !triggerConfig.enabled) {
      print('[TriggerService] Trigger ${context.triggerPoint.name} not enabled for team "${context.teamName}"');
      return null;
    }

    if (triggerConfig.spawn.isEmpty) {
      print('[TriggerService] Trigger ${context.triggerPoint.name} has no agent configured');
      return null;
    }

    // Build the initial prompt with context
    final prompt = _buildTriggerPrompt(context, team);

    // Spawn the agent
    final networkManager = _ref.read(agentNetworkManagerProvider.notifier);

    try {
      // Mark as fired BEFORE spawning to prevent race conditions
      _lastFired[triggerKey] = DateTime.now();

      final agentId = await networkManager.spawnAgent(
        agentType: triggerConfig.spawn,
        name: 'Triggered: ${context.triggerPoint.name}',
        initialPrompt: prompt,
        spawnedBy: 'trigger:${context.triggerPoint.name}',
      );

      print('[TriggerService] Fired ${context.triggerPoint.name} -> spawned ${triggerConfig.spawn}');
      return agentId;
    } catch (e) {
      print('[TriggerService] Error spawning agent for trigger ${context.triggerPoint.name}: $e');
      return null;
    }
  }

  /// Build the initial prompt for a triggered agent.
  String _buildTriggerPrompt(TriggerContext context, TeamDefinition team) {
    final buffer = StringBuffer();

    buffer.writeln('# Triggered Agent');
    buffer.writeln();
    buffer.writeln(context.buildContextSection());

    // Add trigger-specific instructions
    switch (context.triggerPoint) {
      case TriggerPoint.onSessionStart:
        buffer.writeln('## Your Task');
        buffer.writeln();
        buffer.writeln('A new session has started. Review the session context above and perform any initialization work configured for your role.');
        break;

      case TriggerPoint.onSessionEnd:
        buffer.writeln('## Your Task');
        buffer.writeln();
        buffer.writeln('The session is ending. Review what was accomplished and synthesize any knowledge worth preserving.');
        buffer.writeln();
        buffer.writeln('Consider:');
        buffer.writeln('- Important decisions that were made');
        buffer.writeln('- Patterns or approaches that worked well');
        buffer.writeln('- Findings about the codebase');
        buffer.writeln('- Lessons learned');
        break;

      case TriggerPoint.onTaskComplete:
        buffer.writeln('## Your Task');
        buffer.writeln();
        buffer.writeln('The main task has been marked as complete. Review the work that was done.');
        if (context.filesChanged != null && context.filesChanged!.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('Focus on reviewing the changed files listed above.');
        }
        break;

      case TriggerPoint.onAllAgentsIdle:
        buffer.writeln('## Your Task');
        buffer.writeln();
        buffer.writeln('All agents have become idle. This might indicate:');
        buffer.writeln('- Work is complete and ready for synthesis');
        buffer.writeln('- A coordination checkpoint is needed');
        buffer.writeln('- Progress should be reported to the user');
        break;
    }

    return buffer.toString();
  }
}
