import 'agent_id.dart';
import 'agent_status.dart';

/// Metadata about an agent in the network.
///
/// This is persisted along with the agent network and contains
/// human-readable information about each agent.
class AgentMetadata {
  AgentMetadata({
    required this.id,
    required this.name,
    required this.type,
    this.spawnedBy,
    required this.createdAt,
    this.status = AgentStatus.idle,
    this.taskName,
  });

  /// The unique identifier for this agent
  final AgentId id;

  /// A short, human-readable name for this agent (e.g., "Auth Fix", "DB Research")
  final String name;

  /// The type of agent (e.g., "implementation", "contextCollection", "main")
  final String type;

  /// The ID of the agent that spawned this one (null for the main agent)
  final AgentId? spawnedBy;

  /// When this agent was created
  final DateTime createdAt;

  /// The current status of this agent
  final AgentStatus status;

  /// The current task name for this agent (set via setAgentTaskName MCP tool)
  final String? taskName;

  AgentMetadata copyWith({
    AgentId? id,
    String? name,
    String? type,
    AgentId? spawnedBy,
    DateTime? createdAt,
    AgentStatus? status,
    String? taskName,
  }) {
    return AgentMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      spawnedBy: spawnedBy ?? this.spawnedBy,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      taskName: taskName ?? this.taskName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'spawnedBy': spawnedBy,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toStringValue(),
      'taskName': taskName,
    };
  }

  factory AgentMetadata.fromJson(Map<String, dynamic> json) {
    return AgentMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      spawnedBy: json['spawnedBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: _parseStatus(json['status'] as String?),
      taskName: json['taskName'] as String?,
    );
  }

  @override
  String toString() => 'AgentMetadata(id: $id, name: $name, type: $type)';
}

AgentStatus _parseStatus(String? value) {
  if (value == null) return AgentStatus.idle;
  return AgentStatusExtension.fromString(value) ?? AgentStatus.idle;
}
