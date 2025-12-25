import 'package:claude_api/claude_api.dart';
import 'package:riverpod/riverpod.dart';
import '../models/permission.dart';

/// Abstract interface for permission requests
///
/// This abstraction allows vide_core to request permissions without knowing
/// how they're granted. Each UI implementation provides its own:
/// - TUI: Shows permission dialogs to the user
/// - REST: Auto-approve/deny based on rules
abstract class PermissionProvider {
  /// Request permission for a tool invocation
  ///
  /// Returns a [PermissionResponse] indicating whether the operation is allowed.
  Future<PermissionResponse> requestPermission(PermissionRequest request);
}

/// Riverpod provider for PermissionProvider
///
/// This provider MUST be overridden by the UI with the appropriate implementation:
/// - TUI: TUIPermissionAdapter (wraps existing PermissionService)
/// - REST: SimplePermissionService (auto-approve/deny rules)
final permissionProvider = Provider<PermissionProvider>((ref) {
  throw UnimplementedError('PermissionProvider must be overridden by UI');
});

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
final canUseToolCallbackFactoryProvider = Provider<CanUseToolCallbackFactory?>((ref) {
  return null; // Default: no permission checking (auto-allow)
});
