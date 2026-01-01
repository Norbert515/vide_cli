import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';

import '../version.dart';
import 'vide_config_manager.dart';

/// Represents the current state of the auto-update system
enum UpdateStatus {
  /// No update activity
  idle,

  /// Checking GitHub for new releases
  checking,

  /// A new version is available and downloading
  downloading,

  /// Download complete, ready to install on restart
  readyToRestart,

  /// Update check or download failed
  error,

  /// Already on the latest version
  upToDate,
}

/// Information about an available update
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String assetName;
  final int assetSize;
  final String releaseNotes;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.assetName,
    required this.assetSize,
    required this.releaseNotes,
  });

  bool get hasUpdate => _compareVersions(latestVersion, currentVersion) > 0;
}

/// State of the auto-update system
class UpdateState {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final double downloadProgress;
  final String? errorMessage;
  final String currentVersion;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.currentVersion = videVersion,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? updateInfo,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage,
      currentVersion: currentVersion,
    );
  }
}

/// Service that handles checking for updates and downloading them
class AutoUpdateService extends StateNotifier<UpdateState> {
  final VideConfigManager _configManager;
  final http.Client _httpClient;

  AutoUpdateService({
    required VideConfigManager configManager,
    http.Client? httpClient,
  })  : _configManager = configManager,
        _httpClient = httpClient ?? http.Client(),
        super(const UpdateState());

  /// Directory where updates are staged
  String get _updatesDir => path.join(_configManager.configRoot, 'updates');

  /// Path to the pending update binary
  String get _pendingUpdatePath => path.join(_updatesDir, 'pending', _getBinaryName());

  /// Path to metadata file for pending update
  String get _pendingMetadataPath => path.join(_updatesDir, 'pending', 'metadata.json');

  /// Check for updates in the background
  Future<void> checkForUpdates({bool silent = true}) async {
    // Check if auto-updates are disabled via environment variable
    if (Platform.environment['DISABLE_AUTOUPDATER'] == '1') {
      return;
    }

    // Check if auto-updates are disabled via settings
    final settings = _configManager.readGlobalSettings();
    if (!settings.autoUpdatesEnabled) {
      return;
    }

    if (state.status == UpdateStatus.checking || state.status == UpdateStatus.downloading) {
      return; // Already in progress
    }

    state = state.copyWith(status: UpdateStatus.checking);

    try {
      final releaseInfo = await _fetchLatestRelease();

      if (releaseInfo == null) {
        state = state.copyWith(
          status: silent ? UpdateStatus.idle : UpdateStatus.error,
          errorMessage: silent ? null : 'Failed to fetch release info',
        );
        return;
      }

      final latestVersion = releaseInfo['tag_name'] as String;
      final cleanVersion = latestVersion.startsWith('v') ? latestVersion.substring(1) : latestVersion;

      // Find the appropriate asset for this platform
      final asset = _findPlatformAsset(releaseInfo['assets'] as List<dynamic>);

      if (asset == null) {
        state = state.copyWith(
          status: silent ? UpdateStatus.idle : UpdateStatus.error,
          errorMessage: silent ? null : 'No binary available for this platform',
        );
        return;
      }

      final updateInfo = UpdateInfo(
        currentVersion: videVersion,
        latestVersion: cleanVersion,
        downloadUrl: asset['browser_download_url'] as String,
        assetName: asset['name'] as String,
        assetSize: asset['size'] as int,
        releaseNotes: releaseInfo['body'] as String? ?? '',
      );

      if (!updateInfo.hasUpdate) {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          updateInfo: updateInfo,
        );
        return;
      }

      // Check if we already have this update downloaded
      if (await _hasPendingUpdate(cleanVersion)) {
        state = state.copyWith(
          status: UpdateStatus.readyToRestart,
          updateInfo: updateInfo,
        );
        return;
      }

      state = state.copyWith(
        status: UpdateStatus.idle,
        updateInfo: updateInfo,
      );

      // Start background download
      _downloadUpdate(updateInfo);
    } catch (e) {
      state = state.copyWith(
        status: silent ? UpdateStatus.idle : UpdateStatus.error,
        errorMessage: silent ? null : e.toString(),
      );
    }
  }

  /// Download the update in the background
  Future<void> _downloadUpdate(UpdateInfo updateInfo) async {
    state = state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0.0);

    try {
      final pendingDir = Directory(path.dirname(_pendingUpdatePath));
      if (!pendingDir.existsSync()) {
        pendingDir.createSync(recursive: true);
      }

      // Download the binary
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Download failed: HTTP ${response.statusCode}',
        );
        return;
      }

      final totalBytes = response.contentLength ?? updateInfo.assetSize;
      var downloadedBytes = 0;
      final chunks = <List<int>>[];

      await for (final chunk in response.stream) {
        chunks.add(chunk);
        downloadedBytes += chunk.length;
        state = state.copyWith(
          downloadProgress: totalBytes > 0 ? downloadedBytes / totalBytes : 0.0,
        );
      }

      // Write to file
      final bytes = chunks.expand((e) => e).toList();

      // For macOS/Linux tarballs, we need to extract them
      final downloadPath = path.join(pendingDir.path, updateInfo.assetName);
      File(downloadPath).writeAsBytesSync(bytes);

      // Extract if it's a tarball
      if (updateInfo.assetName.endsWith('.tar.gz')) {
        await _extractTarball(downloadPath, pendingDir.path);
        // The extracted binary should be named 'vide'
        final extractedBinary = File(path.join(pendingDir.path, 'vide'));
        if (extractedBinary.existsSync()) {
          extractedBinary.renameSync(_pendingUpdatePath);
        }
        // Clean up the tarball
        File(downloadPath).deleteSync();
      } else {
        // For Windows, the .exe is ready to use
        File(downloadPath).renameSync(_pendingUpdatePath);
      }

      // Make executable on Unix
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', _pendingUpdatePath]);
      }

      // Write metadata
      final metadata = {
        'version': updateInfo.latestVersion,
        'downloadedAt': DateTime.now().toIso8601String(),
        'assetName': updateInfo.assetName,
      };
      File(_pendingMetadataPath).writeAsStringSync(jsonEncode(metadata));

      state = state.copyWith(
        status: UpdateStatus.readyToRestart,
        downloadProgress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download failed: $e',
      );
    }
  }

  /// Extract a tarball using tar command
  Future<void> _extractTarball(String tarPath, String destDir) async {
    final result = await Process.run(
      'tar',
      ['-xzf', tarPath, '-C', destDir],
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to extract tarball: ${result.stderr}');
    }
  }

  /// Fetch the latest release info from GitHub
  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Vide-CLI/$videVersion',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Silently fail - network issues shouldn't crash the app
    }
    return null;
  }

  /// Find the appropriate asset for the current platform
  Map<String, dynamic>? _findPlatformAsset(List<dynamic> assets) {
    final targetName = _getTargetAssetName();

    for (final asset in assets) {
      final assetMap = asset as Map<String, dynamic>;
      final name = assetMap['name'] as String;
      if (name == targetName) {
        return assetMap;
      }
    }
    return null;
  }

  /// Get the expected asset name for the current platform
  String _getTargetAssetName() {
    if (Platform.isMacOS) {
      // Detect ARM vs x64
      final arch = _getMacOSArchitecture();
      return arch == 'arm64' ? 'vide-macos-arm64.tar.gz' : 'vide-macos-x64.tar.gz';
    } else if (Platform.isLinux) {
      return 'vide-linux-x64';
    } else if (Platform.isWindows) {
      return 'vide-windows-x64.exe';
    }
    return '';
  }

  /// Get the binary name for the current platform
  String _getBinaryName() {
    if (Platform.isWindows) {
      return 'vide.exe';
    }
    return 'vide';
  }

  /// Detect macOS architecture
  String _getMacOSArchitecture() {
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      return arch == 'arm64' ? 'arm64' : 'x64';
    } catch (e) {
      return 'x64'; // Default to x64
    }
  }

  /// Check if we have a pending update for the given version
  Future<bool> _hasPendingUpdate(String version) async {
    final metadataFile = File(_pendingMetadataPath);
    if (!metadataFile.existsSync()) return false;

    try {
      final metadata = jsonDecode(metadataFile.readAsStringSync()) as Map<String, dynamic>;
      final pendingVersion = metadata['version'] as String?;
      final binaryExists = File(_pendingUpdatePath).existsSync();
      return pendingVersion == version && binaryExists;
    } catch (e) {
      return false;
    }
  }

  /// Apply the pending update by replacing the current executable
  ///
  /// This should be called on startup if there's a pending update.
  /// Returns true if the update was applied successfully.
  static Future<bool> applyPendingUpdate(VideConfigManager configManager) async {
    final updatesDir = path.join(configManager.configRoot, 'updates');
    final pendingBinaryPath = path.join(
      updatesDir,
      'pending',
      Platform.isWindows ? 'vide.exe' : 'vide',
    );
    final metadataPath = path.join(updatesDir, 'pending', 'metadata.json');

    final pendingBinary = File(pendingBinaryPath);
    final metadataFile = File(metadataPath);

    if (!pendingBinary.existsSync() || !metadataFile.existsSync()) {
      return false;
    }

    try {
      // Get the current executable path
      final currentExe = Platform.resolvedExecutable;

      // On some systems, we can't replace a running executable directly
      // So we use a backup-and-replace strategy
      final backupPath = '$currentExe.backup';

      // Backup current
      if (File(currentExe).existsSync()) {
        File(currentExe).copySync(backupPath);
      }

      // Copy new version
      pendingBinary.copySync(currentExe);

      // Make executable on Unix
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', currentExe]);
      }

      // Clean up pending update
      pendingBinary.deleteSync();
      metadataFile.deleteSync();

      // Remove backup after successful update
      final backup = File(backupPath);
      if (backup.existsSync()) {
        backup.deleteSync();
      }

      return true;
    } catch (e) {
      // If anything fails, try to restore backup
      final currentExe = Platform.resolvedExecutable;
      final backupPath = '$currentExe.backup';
      final backup = File(backupPath);
      if (backup.existsSync()) {
        backup.copySync(currentExe);
        backup.deleteSync();
      }
      return false;
    }
  }

  /// Check if there's a pending update available
  static bool hasPendingUpdateSync(VideConfigManager configManager) {
    final updatesDir = path.join(configManager.configRoot, 'updates');
    final pendingBinaryPath = path.join(
      updatesDir,
      'pending',
      Platform.isWindows ? 'vide.exe' : 'vide',
    );
    final metadataPath = path.join(updatesDir, 'pending', 'metadata.json');

    return File(pendingBinaryPath).existsSync() && File(metadataPath).existsSync();
  }

  /// Get the version of the pending update
  static String? getPendingUpdateVersion(VideConfigManager configManager) {
    final updatesDir = path.join(configManager.configRoot, 'updates');
    final metadataPath = path.join(updatesDir, 'pending', 'metadata.json');
    final metadataFile = File(metadataPath);

    if (!metadataFile.existsSync()) return null;

    try {
      final metadata = jsonDecode(metadataFile.readAsStringSync()) as Map<String, dynamic>;
      return metadata['version'] as String?;
    } catch (e) {
      return null;
    }
  }
}

/// Compare two version strings (e.g., "0.1.0" vs "0.2.0")
/// Returns: positive if v1 > v2, negative if v1 < v2, 0 if equal
int _compareVersions(String v1, String v2) {
  final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  // Pad with zeros to make same length
  while (parts1.length < parts2.length) {
    parts1.add(0);
  }
  while (parts2.length < parts1.length) {
    parts2.add(0);
  }

  for (var i = 0; i < parts1.length; i++) {
    if (parts1[i] > parts2[i]) return 1;
    if (parts1[i] < parts2[i]) return -1;
  }
  return 0;
}

/// Riverpod provider for AutoUpdateService
final autoUpdateServiceProvider = StateNotifierProvider<AutoUpdateService, UpdateState>((ref) {
  final configManager = ref.watch(videConfigManagerProvider);
  return AutoUpdateService(configManager: configManager);
});
