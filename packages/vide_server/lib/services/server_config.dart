import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Server configuration loaded from ~/.vide/api/config.json
///
/// Configuration file format:
/// ```json
/// {
///   "auto-approve-all": false,
///   "filesystem-root": "/Users/chris/projects"
/// }
/// ```
class ServerConfig {
  /// If true, auto-approve all permission requests without prompting
  /// (dangerous, for testing only)
  final bool autoApproveAll;

  /// Root directory for filesystem browsing API.
  /// All filesystem operations are restricted to this directory and below.
  /// Defaults to user's home directory if not specified.
  final String filesystemRoot;

  ServerConfig({this.autoApproveAll = false, String? filesystemRoot})
    : filesystemRoot = filesystemRoot ?? _defaultFilesystemRoot();

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
      'auto-approve-all': autoApproveAll,
      'filesystem-root': filesystemRoot,
    };

    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }
}
