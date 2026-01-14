/// Shared data models for vide client-server communication.

/// Information about a connected client.
final class ConnectedClient {
  final String id;
  final String? remoteAddress;
  final ClientPermission permission;
  final DateTime connectedAt;

  const ConnectedClient({
    required this.id,
    required this.remoteAddress,
    required this.permission,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remote-address': remoteAddress,
        'permission': permission.name,
        'connected-at': connectedAt.toIso8601String(),
      };

  factory ConnectedClient.fromJson(Map<String, dynamic> json) {
    return ConnectedClient(
      id: json['id'] as String,
      remoteAddress: json['remote-address'] as String?,
      permission: ClientPermission.values.byName(json['permission'] as String),
      connectedAt: DateTime.parse(json['connected-at'] as String),
    );
  }
}

/// Permission level for a connected client.
enum ClientPermission {
  /// Can only view the session, cannot send messages.
  view,

  /// Can interact with the session (send messages, respond to permissions).
  interact,
}

/// Information about an agent in the session.
final class AgentInfo {
  final String id;
  final String name;
  final String type;
  final AgentStatus status;

  const AgentInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'status': status.name,
      };

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      status: AgentStatus.values.byName(json['status'] as String),
    );
  }
}

/// Status of an agent.
enum AgentStatus {
  working,
  waitingForAgent,
  waitingForUser,
  idle,
}

/// Information about a session.
final class SessionInfo {
  final String sessionId;
  final String mainAgentId;
  final String? goal;
  final DateTime createdAt;
  final List<AgentInfo> agents;

  const SessionInfo({
    required this.sessionId,
    required this.mainAgentId,
    required this.goal,
    required this.createdAt,
    required this.agents,
  });

  Map<String, dynamic> toJson() => {
        'session-id': sessionId,
        'main-agent-id': mainAgentId,
        'goal': goal,
        'created-at': createdAt.toIso8601String(),
        'agents': agents.map((a) => a.toJson()).toList(),
      };

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId: json['session-id'] as String,
      mainAgentId: json['main-agent-id'] as String,
      goal: json['goal'] as String?,
      createdAt: DateTime.parse(json['created-at'] as String),
      agents: (json['agents'] as List<dynamic>)
          .map((a) => AgentInfo.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Information about the server.
final class ServerInfo {
  final String address;
  final int port;

  const ServerInfo({
    required this.address,
    required this.port,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'port': port,
      };

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      address: json['address'] as String,
      port: json['port'] as int,
    );
  }
}
