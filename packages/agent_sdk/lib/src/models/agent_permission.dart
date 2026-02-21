/// Result of a permission check.
sealed class AgentPermissionResult {
  const AgentPermissionResult();
}

/// Allow the tool to execute.
class AgentPermissionAllow extends AgentPermissionResult {
  final Map<String, dynamic>? updatedInput;
  final List<dynamic>? updatedPermissions;

  const AgentPermissionAllow({this.updatedInput, this.updatedPermissions});
}

/// Deny the tool execution.
class AgentPermissionDeny extends AgentPermissionResult {
  final String message;
  final bool interrupt;

  const AgentPermissionDeny({this.message = '', this.interrupt = false});
}

/// Context provided with each permission check.
class AgentPermissionContext {
  final List<String>? permissionSuggestions;
  final String? blockedPath;

  const AgentPermissionContext({this.permissionSuggestions, this.blockedPath});
}

/// Callback to check whether a tool can be used.
typedef AgentCanUseToolCallback = Future<AgentPermissionResult> Function(
  String toolName,
  Map<String, dynamic> input,
  AgentPermissionContext context,
);
