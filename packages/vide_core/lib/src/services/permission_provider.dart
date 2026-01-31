import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

import '../api/vide_session.dart';
import '../models/agent_id.dart';

/// Handler that manages permission callbacks with late session binding.
///
/// This solves the chicken-egg problem where permission callbacks are needed
/// before the session exists. The handler is created first, then the session
/// is set after creation via [setSession].
///
/// Example:
/// ```dart
/// final handler = PermissionHandler();
/// // ... create network with ClaudeClient using handler.createCallback()
/// final session = VideSession.create(...);
/// handler.setSession(session);  // Now permission callbacks will work
/// ```
class PermissionHandler {
  VideSession? _session;

  /// Set the session for permission handling.
  ///
  /// Must be called after the session is created but before any
  /// permission callbacks are invoked.
  void setSession(VideSession session) {
    _session = session;
  }

  /// Create a permission callback that delegates to the session.
  ///
  /// The callback uses late binding - when invoked, it looks up the session
  /// that was set via [setSession]. If no session is set, auto-allows.
  CanUseToolCallback createCallback({
    required String cwd,
    required AgentId agentId,
    required String? agentName,
    required String? agentType,
  }) {
    return (toolName, input, context) async {
      final session = _session;
      if (session == null) {
        // No session yet - auto-allow (shouldn't happen in practice)
        return const PermissionResultAllow();
      }

      // Delegate to session's permission callback
      final callback = session.createPermissionCallback(
        agentId: agentId.toString(),
        agentName: agentName,
        agentType: agentType,
        cwd: cwd,
      );
      return callback(toolName, input, context);
    };
  }
}

/// Context for creating a canUseTool callback for a specific agent.
///
/// Contains all the information needed to create an appropriate permission
/// callback, including agent identity and configuration.
class PermissionCallbackContext {
  final String cwd;
  final AgentId agentId;
  final String? agentName;
  final String? agentType;
  final String? permissionMode;

  /// The permission handler for late session binding.
  final PermissionHandler? permissionHandler;

  const PermissionCallbackContext({
    required this.cwd,
    required this.agentId,
    this.agentName,
    this.agentType,
    this.permissionMode,
    this.permissionHandler,
  });
}

/// Provider for the permission handler.
///
/// This should be overridden per-session with a PermissionHandler instance.
/// After the session is created, call handler.setSession(session) to enable
/// permission checking.
final permissionHandlerProvider = Provider<PermissionHandler?>((ref) {
  return null; // Default: no permission checking
});
