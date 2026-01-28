import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';

// =============================================================================
// Data Classes
// =============================================================================

/// Permission request for display in the UI.
///
/// All permission requests (local and remote) flow through VideSession.events
/// as PermissionRequestEvent. This class is the UI-friendly wrapper.
class PermissionRequest {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String cwd;
  final DateTime timestamp;
  final String? inferredPattern;

  PermissionRequest({
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    required this.cwd,
    DateTime? timestamp,
    this.inferredPattern,
  }) : timestamp = timestamp ?? DateTime.now();

  PermissionRequest copyWith({String? requestId, String? inferredPattern}) {
    return PermissionRequest(
      requestId: requestId ?? this.requestId,
      toolName: toolName,
      toolInput: toolInput,
      cwd: cwd,
      timestamp: timestamp,
      inferredPattern: inferredPattern ?? this.inferredPattern,
    );
  }

  /// Create a permission request from a PermissionRequestEvent.
  factory PermissionRequest.fromEvent(
    PermissionRequestEvent event,
    String cwd,
  ) {
    return PermissionRequest(
      requestId: event.requestId,
      toolName: event.toolName,
      toolInput: event.toolInput,
      cwd: cwd,
      inferredPattern: event.inferredPattern,
    );
  }

  String get displayAction {
    switch (toolName) {
      case 'Bash':
        return 'Run: ${toolInput['command']}';
      case 'Write':
        return 'Write: ${toolInput['file_path']}';
      case 'Edit':
        return 'Edit: ${toolInput['file_path']}';
      case 'MultiEdit':
        return 'MultiEdit: ${toolInput['file_path']}';
      case 'WebFetch':
        return 'Fetch: ${toolInput['url']}';
      case 'WebSearch':
        return 'Search: ${toolInput['query']}';
      default:
        return 'Use $toolName';
    }
  }
}

/// Provider for permission service (now just a placeholder for backwards compat).
///
/// Permission checking and response handling now flows through VideSession.
/// This provider is kept for any remaining references but may be removed.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Permission service - now a minimal utility class.
///
/// Previously this handled the full permission request/response flow,
/// but that has been unified into VideSession. This class is kept for
/// backwards compatibility and potential future utility methods.
class PermissionService {
  PermissionService();

  /// Dispose resources (currently a no-op)
  void dispose() {}
}
