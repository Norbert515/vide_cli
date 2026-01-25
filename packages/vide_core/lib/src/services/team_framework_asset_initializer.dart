import 'dart:io';
import 'package:path/path.dart' as path;
import '../generated/bundled_team_framework.dart';

/// Service for initializing team framework assets from bundled resources.
///
/// On first app launch, writes bundled .md files to ~/.vide/defaults/
/// if that directory doesn't exist or is missing files.
///
/// In development mode (running from source), it copies from the package
/// assets directory directly. In production mode (compiled binary), it uses
/// the bundled assets that are embedded in the binary at compile time.
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

      // Try filesystem first (development mode), fall back to bundled (production)
      final useFilesystem = _canUseFilesystemAssets();
      if (useFilesystem) {
        await _copyAssetsFromFilesystem(defaultsDir);
      } else {
        await _copyAssetsFromBundled(defaultsDir);
      }

      return true;
    } catch (e) {
      print('Error initializing team framework assets: $e');
      return false;
    }
  }

  /// Check if we can use filesystem assets (development mode).
  static bool _canUseFilesystemAssets() {
    final sourceDir = Directory(_teamFrameworkAssetsPath);
    return sourceDir.existsSync();
  }

  /// Copy assets from bundled constants (production mode).
  static Future<void> _copyAssetsFromBundled(Directory defaultsDir) async {
    for (final category in ['teams', 'agents', 'etiquette']) {
      final categoryDir = Directory(path.join(defaultsDir.path, category));
      await categoryDir.create(recursive: true);

      final assets = bundledTeamFramework[category] ?? {};
      for (final entry in assets.entries) {
        final targetFile = File(
          path.join(categoryDir.path, '${entry.key}.md'),
        );
        await targetFile.writeAsString(entry.value);
      }
    }
  }

  /// Copy assets from filesystem (development mode).
  static Future<void> _copyAssetsFromFilesystem(Directory defaultsDir) async {
    final categories = ['teams', 'agents', 'etiquette'];

    for (final category in categories) {
      final categoryDir = Directory(path.join(defaultsDir.path, category));
      await categoryDir.create(recursive: true);

      final sourcePath = path.join(_teamFrameworkAssetsPath, category);
      final sourceDir = Directory(sourcePath);

      if (!await sourceDir.exists()) {
        print('Warning: Asset directory not found at $sourcePath');
        continue;
      }

      final files = sourceDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.md'),
      );

      for (final file in files) {
        final targetFile = File(
          path.join(categoryDir.path, path.basename(file.path)),
        );
        await file.copy(targetFile.path);
      }
    }
  }

  static String _getVideHome() {
    final home = Platform.environment['HOME'] ?? '';
    return path.join(home, '.vide');
  }
}
