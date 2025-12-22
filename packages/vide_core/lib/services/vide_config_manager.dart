import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';

/// Manages global configuration directory for Vide CLI
///
/// Following Claude Code's approach, this stores project-specific data
/// in a global directory to avoid conflicts with version control.
///
/// Directory structure:
/// - Linux: ~/.config/vide/projects/[encoded-path]/
/// - macOS: ~/Library/Application Support/vide/projects/[encoded-path]/
/// - Windows: %LOCALAPPDATA%\vide\projects\[encoded-path]\
///
/// Path encoding: Replaces forward slashes (/) with hyphens (-)
/// Example: /Users/bob/project -> -Users-bob-project
class VideConfigManager {
  final String _configRoot;

  /// Create a new VideConfigManager with the specified config root directory
  ///
  /// The configRoot parameter specifies the base directory for all config storage.
  /// This allows different UIs (TUI vs REST) to use different config directories.
  VideConfigManager({required String configRoot}) : _configRoot = configRoot {
    // Migrate from legacy parott config if needed
    _migrateFromLegacyConfig();
  }

  /// Migrate configuration from legacy ~/.config/parott directory
  void _migrateFromLegacyConfig() {
    // Note: This migration uses app_dirs which is only available in the TUI
    // For REST API, this will be a no-op since we're not migrating legacy config
    try {
      // Skip migration if app_dirs is not available (e.g., in REST server context)
      // This will be handled by the TUI when it creates its VideConfigManager instance
    } catch (e) {
      // Silently skip migration if it fails
    }
  }

  /// Get the storage directory for a specific project
  ///
  /// Takes an absolute project path and returns the corresponding
  /// global config directory for that project.
  ///
  /// The directory is created if it doesn't exist.
  String getProjectStorageDir(String projectPath) {
    final absolutePath = path.absolute(projectPath);
    final encodedPath = _encodeProjectPath(absolutePath);

    final projectDir = path.join(_configRoot, 'projects', encodedPath);

    // Ensure directory exists
    Directory(projectDir).createSync(recursive: true);

    return projectDir;
  }

  /// Get the root config directory
  String get configRoot => _configRoot;

  /// Encode a project path following Claude Code's approach
  ///
  /// Replaces forward slashes (/) with hyphens (-)
  /// Example: /Users/bob/project -> -Users-bob-project
  String _encodeProjectPath(String absolutePath) {
    // Normalize the path first to handle trailing slashes, etc.
    final normalized = path.normalize(absolutePath);

    // Replace path separators with hyphens
    // On Windows, also handle backslashes
    String encoded = normalized.replaceAll('/', '-');
    if (Platform.isWindows) {
      encoded = encoded.replaceAll('\\', '-');
    }

    return encoded;
  }

  /// List all project directories
  ///
  /// Returns a list of encoded project paths that have storage directories
  List<String> listProjects() {
    final projectsDir = Directory(path.join(_configRoot, 'projects'));
    if (!projectsDir.existsSync()) {
      return [];
    }

    return projectsDir
        .listSync()
        .whereType<Directory>()
        .map((dir) => path.basename(dir.path))
        .toList();
  }
}

/// Riverpod provider for VideConfigManager
///
/// This provider MUST be overridden by the UI with the appropriate config root:
/// - TUI: ~/.vide
/// - REST: ~/.vide/api
final videConfigManagerProvider = Provider<VideConfigManager>((ref) {
  throw UnimplementedError('VideConfigManager must be overridden by UI');
});
