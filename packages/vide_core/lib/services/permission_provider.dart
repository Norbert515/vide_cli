import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

import '../models/agent_id.dart';

/// Context for creating a canUseTool callback for a specific agent.
///
/// Contains all the information needed to create an appropriate permission
/// callback, including agent identity and configuration.
class PermissionCallbackContext {
  final String cwd;
  final AgentId agentId;
  final String? agentName;
  final String? permissionMode;
  final String? networkId; // Session ID in REST API terms

  const PermissionCallbackContext({
    required this.cwd,
    required this.agentId,
    this.agentName,
    this.permissionMode,
    this.networkId,
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
typedef CanUseToolCallbackFactory = CanUseToolCallback Function(
  PermissionCallbackContext context,
);

/// Riverpod provider for the canUseTool callback factory.
///
/// This provider MUST be overridden by the UI with the appropriate implementation:
/// - TUI: Uses PermissionService.checkToolPermission
/// - REST: Uses createRestPermissionCallback or createInteractivePermissionCallback
///
/// If not overridden, returns null (no permission checking).
final canUseToolCallbackFactoryProvider = Provider<CanUseToolCallbackFactory?>((
  ref,
) {
  return null; // Default: no permission checking (auto-allow)
});
