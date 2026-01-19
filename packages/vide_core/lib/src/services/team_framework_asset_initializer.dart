import 'dart:io';
import 'package:path/path.dart' as path;

/// Service for initializing team framework assets from package resources.
///
/// On first app launch, copies default .md files from package assets to
/// ~/.vide/defaults/ if that directory doesn't exist or is missing files.
class TeamFrameworkAssetInitializer {
  static const _teamFrameworkAssetsPath =
      'packages/vide_core/assets/team_framework';

  /// Initialize team framework assets.
  ///
  /// By default, only copies if defaults directory is empty.
  /// Set [forceSync] to true to always overwrite with latest assets.
  ///
  /// Returns true if initialization succeeded or was not needed.
  static Future<bool> initialize({
    String? videHome,
    bool forceSync = false,
  }) async {
    try {
      final home = videHome ?? _getVideHome();
      final defaultsDir = Directory(path.join(home, 'defaults'));

      // If not forcing sync and defaults directory exists with content, we're good
      if (!forceSync && await defaultsDir.exists()) {
        final files = defaultsDir.listSync(recursive: true);
        if (files.isNotEmpty) {
          return true;
        }
      }

      // Create the defaults directory if it doesn't exist
      await defaultsDir.create(recursive: true);

      // Copy assets from package to defaults
      await _copyAssetsToDefaults(defaultsDir);

      return true;
    } catch (e) {
      print('Error initializing team framework assets: $e');
      return false;
    }
  }

  /// Copy all assets from package to defaults directory
  static Future<void> _copyAssetsToDefaults(Directory defaultsDir) async {
    final categories = ['teams', 'agents', 'roles', 'etiquette'];

    for (final category in categories) {
      final categoryDir =
          Directory(path.join(defaultsDir.path, category));
      await categoryDir.create(recursive: true);

      // Copy from package assets
      await _copyAssetsFromPackage(
        sourcePath: path.join(_teamFrameworkAssetsPath, category),
        targetDir: categoryDir,
      );
    }
  }

  /// Copy assets from package directory to target directory
  static Future<void> _copyAssetsFromPackage({
    required String sourcePath,
    required Directory targetDir,
  }) async {
    try {
      // Try to read from the source path as if it exists in the filesystem
      final sourceDir = Directory(sourcePath);

      if (!await sourceDir.exists()) {
        print('Warning: Asset directory not found at $sourcePath');
        return;
      }

      final files = sourceDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'));

      for (final file in files) {
        final targetFile = File(
          path.join(targetDir.path, path.basename(file.path)),
        );
        await file.copy(targetFile.path);
      }
    } catch (e) {
      print('Error copying assets from $sourcePath: $e');
      // Continue gracefully - assets might be bundled differently
      // in some deployment scenarios
    }
  }

  static String _getVideHome() {
    final home = Platform.environment['HOME'] ?? '';
    return path.join(home, '.vide');
  }
}
