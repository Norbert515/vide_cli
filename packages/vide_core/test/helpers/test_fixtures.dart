import 'package:vide_core/vide_core.dart';

/// Factory functions for creating test objects
class TestFixtures {
  /// Create a test AgentMetadata
  static AgentMetadata agentMetadata({
    String? id,
    String name = 'Test Agent',
    String type = 'implementation',
    String? spawnedBy,
    DateTime? createdAt,
    AgentStatus status = AgentStatus.idle,
    String? taskName,
  }) {
    return AgentMetadata(
      id: id ?? 'agent-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      type: type,
      spawnedBy: spawnedBy,
      createdAt: createdAt ?? DateTime.now(),
      status: status,
      taskName: taskName,
    );
  }

  /// Create a test AgentNetwork
  static AgentNetwork agentNetwork({
    String? id,
    String goal = 'Test Goal',
    List<AgentMetadata>? agents,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? worktreePath,
  }) {
    return AgentNetwork(
      id: id ?? 'network-${DateTime.now().microsecondsSinceEpoch}',
      goal: goal,
      agents: agents ?? [agentMetadata(type: 'main', name: 'Main')],
      createdAt: createdAt ?? DateTime.now(),
      lastActiveAt: lastActiveAt,
      worktreePath: worktreePath,
    );
  }

  /// Create a test MemoryEntry
  static MemoryEntry memoryEntry({
    String key = 'test_key',
    String value = 'test_value',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryEntry(
      key: key,
      value: value,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
    );
  }

  /// Create a test ClaudeSettings
  static ClaudeSettings claudeSettings({
    List<String>? allow,
    List<String>? deny,
  }) {
    return ClaudeSettings(
      permissions: PermissionsConfig(
        allow: allow ?? [],
        deny: deny ?? [],
        ask: [],
      ),
    );
  }
}
