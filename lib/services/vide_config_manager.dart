import 'dart:io';
import 'package:app_dirs/app_dirs.dart';
import 'package:path/path.dart' as path;

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
  VideConfigManager._();

  static final VideConfigManager _instance = VideConfigManager._();

  /// Get the singleton instance
  factory VideConfigManager() => _instance;

  late final String _configRoot;
  bool _initialized = false;

  /// Initialize the config manager
  /// This must be called before using other methods
  void initialize() {
    if (_initialized) return;

    // Check for environment variable override first
    final envConfig = Platform.environment['VIDE_CONFIG_DIR'];
    if (envConfig != null && envConfig.isNotEmpty) {
      _configRoot = envConfig;
    } else {
      // Use app_dirs for cross-platform config directory
      final appDirs = getAppDirs(application: 'vide');
      _configRoot = appDirs.config;
    }

    // Migrate from legacy parott config if needed
    _migrateFromLegacyConfig();

    _initialized = true;
  }

  /// Migrate configuration from legacy ~/.config/parott directory
  void _migrateFromLegacyConfig() {
    final legacyAppDirs = getAppDirs(application: 'parott');
    final legacyDir = Directory(legacyAppDirs.config);

    if (legacyDir.existsSync() && !Directory(_configRoot).existsSync()) {
      try {
        legacyDir.renameSync(_configRoot);
      } catch (e) {
        // If rename fails (cross-device), fall back to copy
        // For now, just log and continue - user can manually migrate
      }
    }
  }

  /// Get the storage directory for a specific project
  ///
  /// Takes an absolute project path and returns the corresponding
  /// global config directory for that project.
  ///
  /// The directory is created if it doesn't exist.
  String getProjectStorageDir(String projectPath) {
    if (!_initialized) {
      throw StateError('VideConfigManager must be initialized before use');
    }

    final absolutePath = path.absolute(projectPath);
    final encodedPath = _encodeProjectPath(absolutePath);

    final projectDir = path.join(_configRoot, 'projects', encodedPath);

    // Ensure directory exists
    Directory(projectDir).createSync(recursive: true);

    return projectDir;
  }

  /// Get the root config directory
  String get configRoot {
    if (!_initialized) {
      throw StateError('VideConfigManager must be initialized before use');
    }
    return _configRoot;
  }

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
    if (!_initialized) {
      throw StateError('VideConfigManager must be initialized before use');
    }

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
