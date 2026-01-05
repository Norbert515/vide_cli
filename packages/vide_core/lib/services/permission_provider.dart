import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';

/// Factory function type for creating canUseTool callbacks.
///
/// The factory takes a working directory (cwd) and returns a [CanUseToolCallback]
/// that can be passed to [ClaudeClient.create].
///
/// This design allows each agent to have its own cwd while sharing the
/// underlying permission logic.
typedef CanUseToolCallbackFactory = CanUseToolCallback Function(String cwd);

/// Riverpod provider for the canUseTool callback factory.
///
/// This provider MUST be overridden by the UI with the appropriate implementation:
/// - TUI: Uses PermissionService.checkToolPermission
/// - REST: Could use auto-approve/deny rules
///
/// If not overridden, returns null (no permission checking).
final canUseToolCallbackFactoryProvider = Provider<CanUseToolCallbackFactory?>((
  ref,
) {
  return null; // Default: no permission checking (auto-allow)
});
