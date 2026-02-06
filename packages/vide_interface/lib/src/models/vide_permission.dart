/// Permission types for the Vide interface boundary.
///
/// Replaces claude_sdk's PermissionResult at the public API surface.
library;

/// Result of a permission check.
sealed class VidePermissionResult {
  const VidePermissionResult();
}

/// Permission was granted.
class VidePermissionAllow extends VidePermissionResult {
  /// Updated input parameters (e.g., with AskUserQuestion answers).
  final Map<String, dynamic>? updatedInput;

  const VidePermissionAllow({this.updatedInput});
}

/// Permission was denied.
class VidePermissionDeny extends VidePermissionResult {
  /// Reason for denial.
  final String message;

  const VidePermissionDeny({required this.message});
}

/// Context provided with a permission check request.
class VidePermissionContext {
  /// Suggested permission patterns to add.
  final List<String>? permissionSuggestions;

  /// Path that was blocked (if applicable).
  final String? blockedPath;

  const VidePermissionContext({this.permissionSuggestions, this.blockedPath});
}

/// Callback type for checking tool permissions.
typedef VideCanUseToolCallback =
    Future<VidePermissionResult> Function(
      String toolName,
      Map<String, dynamic> input,
      VidePermissionContext context,
    );
