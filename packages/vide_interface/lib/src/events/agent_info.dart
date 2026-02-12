/// Agent metadata attached to events.
library;

/// Metadata about the agent that produced an event.
class AgentInfo {
  final String id;
  final String type;
  final String name;
  final String? taskName;

  /// Current agent status (e.g. 'working', 'idle').
  ///
  /// Only present in ConnectedEvent agent lists. Null when AgentInfo is used
  /// as attribution on regular events.
  final String? status;

  const AgentInfo({
    required this.id,
    required this.type,
    required this.name,
    this.taskName,
    this.status,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
    id: json['agent-id'] as String? ?? json['id'] as String? ?? '',
    type: json['agent-type'] as String? ?? json['type'] as String? ?? '',
    name: json['agent-name'] as String? ?? json['name'] as String? ?? 'Agent',
    taskName: json['task-name'] as String?,
    status: json['status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'agent-id': id,
    'agent-type': type,
    'agent-name': name,
    if (taskName != null) 'task-name': taskName,
    if (status != null) 'status': status,
  };
}
