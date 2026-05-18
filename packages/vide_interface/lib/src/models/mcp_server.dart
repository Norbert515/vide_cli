/// MCP server status types for the Vide ecosystem.
///
/// These are transport-independent models — both local and remote
/// sessions produce/consume them without depending on any specific
/// agent SDK.
library;

/// Connection status of an MCP server.
enum VideMcpServerStatus {
  connected,
  connecting,
  failed,
  disconnected;

  static VideMcpServerStatus fromString(String value) {
    return VideMcpServerStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VideMcpServerStatus.disconnected,
    );
  }

  String toWireString() => name;
}

/// Status information for a single MCP server.
class VideMcpServerInfo {
  /// Server name (as configured in .mcp.json).
  final String name;

  /// Current connection status.
  final VideMcpServerStatus status;

  /// Error message if [status] is [VideMcpServerStatus.failed].
  final String? error;

  const VideMcpServerInfo({
    required this.name,
    required this.status,
    this.error,
  });

  factory VideMcpServerInfo.fromJson(Map<String, dynamic> json) {
    return VideMcpServerInfo(
      name: json['name'] as String,
      status: VideMcpServerStatus.fromString(json['status'] as String? ?? ''),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.toWireString(),
    if (error != null) 'error': error,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideMcpServerInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          status == other.status &&
          error == other.error;

  @override
  int get hashCode => Object.hash(name, status, error);

  @override
  String toString() =>
      'VideMcpServerInfo(name: $name, status: $status, error: $error)';
}
