/// Status of an MCP server
enum McpServerStatus { connected, error, stopped, unknown }

/// Scope/origin of an MCP server
enum McpServerScope {
  builtin, // Vide's internal servers
  project, // From .mcp.json
  local, // From ~/.claude.json per-project
  user, // From ~/.claude.json global
  managed, // Enterprise managed
}

/// Information about a single MCP server
class McpServerInfo {
  final String name;
  final McpServerStatus status;
  final McpServerScope scope;
  final bool isManaged;
  final int? port;
  final List<String> tools;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const McpServerInfo({
    required this.name,
    required this.status,
    required this.scope,
    this.isManaged = false,
    this.port,
    this.tools = const [],
    this.errorMessage,
    this.lastUpdated,
  });

  McpServerInfo copyWith({
    String? name,
    McpServerStatus? status,
    McpServerScope? scope,
    bool? isManaged,
    int? port,
    List<String>? tools,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return McpServerInfo(
      name: name ?? this.name,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      isManaged: isManaged ?? this.isManaged,
      port: port ?? this.port,
      tools: tools ?? this.tools,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory McpServerInfo.fromInitMessage(Map<String, dynamic> json) {
    return McpServerInfo(
      name: json['name'] as String,
      status: json['status'] == 'connected'
          ? McpServerStatus.connected
          : McpServerStatus.error,
      scope: McpServerScope.local, // Default, CLI doesn't report scope
      isManaged: false,
      errorMessage: json['error'] as String?,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'status': status.name,
      'scope': scope.name,
      'isManaged': isManaged,
      'port': port,
      'tools': tools,
      'errorMessage': errorMessage,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory McpServerInfo.fromJson(Map<String, dynamic> json) {
    return McpServerInfo(
      name: json['name'] as String,
      status: McpServerStatus.values.byName(json['status'] as String),
      scope: McpServerScope.values.byName(json['scope'] as String),
      isManaged: json['isManaged'] as bool? ?? false,
      port: json['port'] as int?,
      tools: (json['tools'] as List?)?.cast<String>() ?? const [],
      errorMessage: json['errorMessage'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  @override
  String toString() => 'McpServerInfo(name: $name, status: $status)';
}

/// Aggregate MCP state for an agent session
class AgentMcpState {
  final List<McpServerInfo> servers;
  final List<String> availableTools;
  final DateTime? lastInitReceived;

  // Session capabilities from init message
  final List<String> skills;
  final List<String> agents;
  final List<String> slashCommands;
  final List<Map<String, dynamic>> plugins;
  final String? permissionMode;
  final String? claudeCodeVersion;
  final String? model;
  final String? cwd;

  const AgentMcpState({
    this.servers = const [],
    this.availableTools = const [],
    this.lastInitReceived,
    this.skills = const [],
    this.agents = const [],
    this.slashCommands = const [],
    this.plugins = const [],
    this.permissionMode,
    this.claudeCodeVersion,
    this.model,
    this.cwd,
  });

  List<McpServerInfo> get builtinServers =>
      servers.where((s) => s.scope == McpServerScope.builtin).toList();

  List<McpServerInfo> get externalServers =>
      servers.where((s) => s.scope != McpServerScope.builtin).toList();

  List<McpServerInfo> get connectedServers =>
      servers.where((s) => s.status == McpServerStatus.connected).toList();

  List<McpServerInfo> get errorServers =>
      servers.where((s) => s.status == McpServerStatus.error).toList();

  AgentMcpState copyWith({
    List<McpServerInfo>? servers,
    List<String>? availableTools,
    DateTime? lastInitReceived,
    List<String>? skills,
    List<String>? agents,
    List<String>? slashCommands,
    List<Map<String, dynamic>>? plugins,
    String? permissionMode,
    String? claudeCodeVersion,
    String? model,
    String? cwd,
  }) {
    return AgentMcpState(
      servers: servers ?? this.servers,
      availableTools: availableTools ?? this.availableTools,
      lastInitReceived: lastInitReceived ?? this.lastInitReceived,
      skills: skills ?? this.skills,
      agents: agents ?? this.agents,
      slashCommands: slashCommands ?? this.slashCommands,
      plugins: plugins ?? this.plugins,
      permissionMode: permissionMode ?? this.permissionMode,
      claudeCodeVersion: claudeCodeVersion ?? this.claudeCodeVersion,
      model: model ?? this.model,
      cwd: cwd ?? this.cwd,
    );
  }
}
