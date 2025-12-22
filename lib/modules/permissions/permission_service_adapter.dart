import 'package:vide_core/vide_core.dart' as core;
import 'permission_service.dart' as tui;

/// TUI implementation of PermissionProvider
///
/// Note: The TUI uses a hook-based permission system where permission requests
/// come from an external HTTP server, get queued in PermissionScope, shown in
/// dialogs, and responses are sent back through the server.
///
/// This adapter is currently not used in the TUI's permission flow, but exists
/// to satisfy the vide_core provider interface for potential future use.
class TUIPermissionAdapter implements core.PermissionProvider {
  // ignore: unused_field
  final tui.PermissionService _service;

  TUIPermissionAdapter(this._service);

  @override
  Future<core.PermissionResponse> requestPermission(core.PermissionRequest request) {
    // The TUI's permission system works via hook-based HTTP requests,
    // not programmatic Dart calls. Permission requests flow through:
    // 1. Claude Code hook → HTTP POST to PermissionService server
    // 2. PermissionService emits to stream
    // 3. PermissionScope listens and queues requests
    // 4. UI shows permission dialog
    // 5. User responds → PermissionService.respondToPermission()
    // 6. HTTP response sent back to hook
    //
    // If vide_core services ever need to request permissions programmatically,
    // this method would need to be implemented to bridge to the TUI's
    // stream-based permission flow.
    throw UnimplementedError(
      'TUI permissions are handled via hook server, not programmatic requests. '
      'Direct permission requests from vide_core are not yet supported in the TUI.',
    );
  }
}
