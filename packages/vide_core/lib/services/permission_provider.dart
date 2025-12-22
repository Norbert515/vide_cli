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
