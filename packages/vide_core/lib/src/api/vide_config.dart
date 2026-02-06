/// Configuration classes for the VideCore API.
///
/// VideSessionConfig and VideSessionInfo are defined in vide_interface
/// and re-exported here. VideCoreConfig is local to vide_core since it
/// depends on PermissionHandler.
library;

import '../services/permission_provider.dart';

// Re-export shared types from vide_interface
export 'package:vide_interface/vide_interface.dart'
    show VideSessionConfig, VideSessionInfo;

/// Configuration for creating a [VideCore] instance.
///
/// Example:
/// ```dart
/// final core = VideCore(VideCoreConfig(
///   configDir: '~/.vide',
/// ));
/// ```
class VideCoreConfig {
  /// Configuration directory for persisting sessions and settings.
  ///
  /// Defaults to `~/.vide` if not specified.
  final String? configDir;

  /// Permission handler for processing tool permission requests.
  ///
  /// Required for security - this handler controls which tools agents can use.
  /// The handler will be bound to each session after creation via
  /// [PermissionHandler.setSession].
  final PermissionHandler permissionHandler;

  const VideCoreConfig({this.configDir, required this.permissionHandler});
}
