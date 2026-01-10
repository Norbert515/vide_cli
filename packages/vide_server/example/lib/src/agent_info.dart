/// Agent metadata attached to events.
class AgentInfo {
  final String id;
  final String type;
  final String name;
  final String? taskName;

  const AgentInfo({
    required this.id,
    required this.type,
    required this.name,
    this.taskName,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
        id: json['agent-id'] as String? ?? json['id'] as String? ?? '',
        type: json['agent-type'] as String? ?? json['type'] as String? ?? '',
        name: json['agent-name'] as String? ?? json['name'] as String? ?? 'Agent',
        taskName: json['task-name'] as String?,
      );
}
