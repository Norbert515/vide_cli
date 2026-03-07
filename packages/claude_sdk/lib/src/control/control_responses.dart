/// Control Protocol Response Types
///
/// These represent responses from Claude CLI control requests like
/// mcp_status, set_model, etc.

/// Status of an MCP server connection
enum McpServerStatus {
  connected,
  connecting,
  failed,
  disconnected;

  static McpServerStatus fromString(String value) {
    return McpServerStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => McpServerStatus.disconnected,
    );
  }
}

/// Information about an MCP server from the CLI
class McpServerStatusInfo {
  /// Server name
  final String name;

  /// Connection status
  final McpServerStatus status;

  /// Server info (name, version) if connected
  final McpServerInfo? serverInfo;

  /// Error message if failed
  final String? error;

  const McpServerStatusInfo({
    required this.name,
    required this.status,
    this.serverInfo,
    this.error,
  });

  factory McpServerStatusInfo.fromJson(Map<String, dynamic> json) {
    return McpServerStatusInfo(
      name: json['name'] as String,
      status: McpServerStatus.fromString(json['status'] as String? ?? ''),
      serverInfo: json['serverInfo'] != null
          ? McpServerInfo.fromJson(json['serverInfo'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    if (serverInfo != null) 'serverInfo': serverInfo!.toJson(),
    if (error != null) 'error': error,
  };

  @override
  String toString() =>
      'McpServerStatusInfo(name: $name, status: $status, error: $error)';
}

/// Server info returned for connected MCP servers
class McpServerInfo {
  /// Server name from capabilities
  final String name;

  /// Server version
  final String version;

  const McpServerInfo({required this.name, required this.version});

  factory McpServerInfo.fromJson(Map<String, dynamic> json) {
    return McpServerInfo(
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'version': version};
}

/// Response from mcp_status control request
class McpStatusResponse {
  /// List of MCP servers and their status
  final List<McpServerStatusInfo> servers;

  const McpStatusResponse({required this.servers});

  factory McpStatusResponse.fromJson(Map<String, dynamic> json) {
    final serversJson = json['mcpServers'] as List<dynamic>? ?? [];
    return McpStatusResponse(
      servers: serversJson
          .map((s) => McpServerStatusInfo.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get only connected servers
  List<McpServerStatusInfo> get connectedServers =>
      servers.where((s) => s.status == McpServerStatus.connected).toList();

  /// Get only failed servers
  List<McpServerStatusInfo> get failedServers =>
      servers.where((s) => s.status == McpServerStatus.failed).toList();

  @override
  String toString() => 'McpStatusResponse(servers: $servers)';
}

/// Response from set_model control request
class SetModelResponse {
  /// The new model that was set
  final String? model;

  /// Whether the operation succeeded
  final bool success;

  const SetModelResponse({this.model, this.success = true});

  factory SetModelResponse.fromJson(Map<String, dynamic> json) {
    return SetModelResponse(model: json['model'] as String?, success: true);
  }
}

/// Response from set_permission_mode control request
class SetPermissionModeResponse {
  /// The new permission mode that was set
  final String? mode;

  /// Whether the operation succeeded
  final bool success;

  const SetPermissionModeResponse({this.mode, this.success = true});

  factory SetPermissionModeResponse.fromJson(Map<String, dynamic> json) {
    return SetPermissionModeResponse(
      mode: json['mode'] as String?,
      success: true,
    );
  }
}

/// Response from set_max_thinking_tokens control request
class SetMaxThinkingTokensResponse {
  /// The new max thinking tokens value
  final int? maxThinkingTokens;

  /// Whether the operation succeeded
  final bool success;

  const SetMaxThinkingTokensResponse({
    this.maxThinkingTokens,
    this.success = true,
  });

  factory SetMaxThinkingTokensResponse.fromJson(Map<String, dynamic> json) {
    return SetMaxThinkingTokensResponse(
      maxThinkingTokens: json['max_thinking_tokens'] as int?,
      success: true,
    );
  }
}

/// Response from interrupt control request
class InterruptResponse {
  /// Whether the interrupt succeeded
  final bool success;

  const InterruptResponse({this.success = true});

  factory InterruptResponse.fromJson(Map<String, dynamic> json) {
    return const InterruptResponse(success: true);
  }
}

/// Response from rewind_files control request
class RewindFilesResponse {
  /// Whether the rewind succeeded
  final bool success;

  /// Number of files rewound
  final int? filesRewound;

  const RewindFilesResponse({this.success = true, this.filesRewound});

  factory RewindFilesResponse.fromJson(Map<String, dynamic> json) {
    return RewindFilesResponse(
      success: true,
      filesRewound: json['files_rewound'] as int?,
    );
  }
}

/// Response from get_settings control request
class GetSettingsResponse {
  /// The effective merged settings (all sources combined)
  final Map<String, dynamic> effective;

  /// Per-source settings breakdown
  final List<SettingsSource> sources;

  const GetSettingsResponse({
    required this.effective,
    required this.sources,
  });

  /// Get a specific setting value from effective settings
  T? getSetting<T>(String key) => effective[key] as T?;

  /// Current effort level from effective settings
  String? get effortLevel => effective['effortLevel'] as String?;

  /// Current model from effective settings
  String? get model => effective['model'] as String?;

  /// Current permission mode default from effective settings
  String? get permissionMode {
    final permissions = effective['permissions'] as Map<String, dynamic>?;
    return permissions?['defaultMode'] as String?;
  }

  /// Available models restriction from effective settings
  List<String>? get availableModels {
    final models = effective['availableModels'] as List?;
    return models?.cast<String>();
  }

  factory GetSettingsResponse.fromJson(Map<String, dynamic> json) {
    final sourcesJson = json['sources'] as List<dynamic>? ?? [];
    return GetSettingsResponse(
      effective: json['effective'] as Map<String, dynamic>? ?? {},
      sources: sourcesJson
          .map((s) => SettingsSource.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() =>
      'GetSettingsResponse(effective: $effective, sources: $sources)';
}

/// A settings source with its name and settings values
class SettingsSource {
  /// Source name (e.g., 'userSettings', 'projectSettings', 'localSettings', 'flagSettings')
  final String source;

  /// Settings values from this source
  final Map<String, dynamic> settings;

  const SettingsSource({required this.source, required this.settings});

  factory SettingsSource.fromJson(Map<String, dynamic> json) {
    return SettingsSource(
      source: json['source'] as String? ?? '',
      settings: json['settings'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  String toString() => 'SettingsSource(source: $source, settings: $settings)';
}

/// MCP server configuration for mcp_set_servers
class McpServerConfig {
  /// Server name
  final String name;

  /// Command to run
  final String command;

  /// Command arguments
  final List<String> args;

  /// Environment variables
  final Map<String, String>? env;

  const McpServerConfig({
    required this.name,
    required this.command,
    this.args = const [],
    this.env,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'command': command,
    'args': args,
    if (env != null) 'env': env,
  };
}
