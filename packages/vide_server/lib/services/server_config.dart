import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Server configuration loaded from ~/.vide/api/config.json
///
/// Configuration file format:
/// ```json
/// {
///   "permission-timeout-seconds": 0,
///   "auto-approve-all": false,
///   "filesystem-root": "/Users/chris/projects"
/// }
/// ```
class ServerConfig {
  /// Timeout for permission requests in seconds.
  /// Default is 0 (no timeout) - user can take as long as needed to respond.
  /// Set to a positive value to auto-deny after that many seconds.
  final int permissionTimeoutSeconds;

  /// If true, auto-approve all permission requests without prompting
  /// (dangerous, for testing only)
  final bool autoApproveAll;

  /// Root directory for filesystem browsing API.
  /// All filesystem operations are restricted to this directory and below.
  /// Defaults to user's home directory if not specified.
  final String filesystemRoot;

  ServerConfig({
    this.permissionTimeoutSeconds = 0,
    this.autoApproveAll = false,
    String? filesystemRoot,
  }) : filesystemRoot = filesystemRoot ?? _defaultFilesystemRoot();

  static String _defaultFilesystemRoot() {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
  }

  /// Default configuration
  static final defaultConfig = ServerConfig();

  /// Load configuration from ~/.vide/api/config.json
  ///
  /// Returns default config if file doesn't exist or is invalid.
  static Future<ServerConfig> load() async {
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final configPath = p.join(homeDir, '.vide', 'api', 'config.json');

    final configFile = File(configPath);
    if (!await configFile.exists()) {
      return defaultConfig;
    }

    final content = await configFile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    return ServerConfig(
      permissionTimeoutSeconds: json['permission-timeout-seconds'] as int? ?? 0,
      autoApproveAll: json['auto-approve-all'] as bool? ?? false,
      filesystemRoot: json['filesystem-root'] as String?,
    );
  }

  /// Save configuration to ~/.vide/api/config.json
  Future<void> save() async {
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final configPath = p.join(homeDir, '.vide', 'api', 'config.json');

    final configFile = File(configPath);
    await configFile.parent.create(recursive: true);

    final json = {
      'permission-timeout-seconds': permissionTimeoutSeconds,
      'auto-approve-all': autoApproveAll,
      'filesystem-root': filesystemRoot,
    };

    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  /// Duration for permission timeout
  Duration get permissionTimeout => Duration(seconds: permissionTimeoutSeconds);
}
