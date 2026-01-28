import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

import '../api/vide_session.dart';
import '../models/agent_id.dart';

/// Function type for looking up a VideSession by network ID.
///
/// Returns null if no session exists for the given network ID.
typedef SessionLookup = VideSession? Function(String networkId);

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
  final String? networkId; // Session ID in REST API terms

  /// Function to look up the session at callback invocation time.
  /// This enables late-binding where the session may not exist when
  /// the callback is created, but will exist when it's invoked.
  final SessionLookup? sessionLookup;

  const PermissionCallbackContext({
    required this.cwd,
    required this.agentId,
    this.agentName,
    this.agentType,
    this.permissionMode,
    this.networkId,
    this.sessionLookup,
  });
}

/// Factory function type for creating canUseTool callbacks.
///
/// The factory takes a [PermissionCallbackContext] containing the working
/// directory and agent context, and returns a [CanUseToolCallback] that can
/// be passed to [ClaudeClient.create].
///
/// This design allows each agent to have its own cwd and permission behavior
/// while sharing the underlying permission logic.
typedef CanUseToolCallbackFactory =
    CanUseToolCallback Function(PermissionCallbackContext context);

/// Riverpod provider for the canUseTool callback factory.
///
/// This provider MUST be overridden by the UI with the appropriate implementation:
/// - TUI: Uses session-based permission checking via VideSession
/// - REST: Uses createRestPermissionCallback or createInteractivePermissionCallback
///
/// If not overridden, returns null (no permission checking).
final canUseToolCallbackFactoryProvider = Provider<CanUseToolCallbackFactory?>((
  ref,
) {
  return null; // Default: no permission checking (auto-allow)
});

/// Provider for the session lookup function.
///
/// This is used by the permission callback factory to resolve sessions
/// at invocation time (late binding).
final sessionLookupProvider = Provider<SessionLookup?>((ref) {
  return null; // Default: no session lookup
});
