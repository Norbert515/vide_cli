import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// App-wide settings for Vide CLI (separate from Claude settings)
class VideSettings {
  final bool codeSommelierEnabled;

  const VideSettings({
    this.codeSommelierEnabled = false,
  });

  VideSettings copyWith({bool? codeSommelierEnabled}) {
    return VideSettings(
      codeSommelierEnabled: codeSommelierEnabled ?? this.codeSommelierEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'codeSommelierEnabled': codeSommelierEnabled,
  };

  factory VideSettings.fromJson(Map<String, dynamic> json) {
    return VideSettings(
      codeSommelierEnabled: json['codeSommelierEnabled'] as bool? ?? false,
    );
  }

  static VideSettings defaults() => const VideSettings();
}

/// Singleton manager for Vide app settings
class VideSettingsManager {
  static final VideSettingsManager instance = VideSettingsManager._();
  VideSettingsManager._();

  VideSettings _settings = VideSettings.defaults();
  bool _loaded = false;

  VideSettings get settings => _settings;

  String get _settingsPath {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return path.join(homeDir, '.vide', 'vide_settings.json');
  }

  /// Load settings from disk (call once at startup)
  Future<void> load() async {
    if (_loaded) return;

    try {
      final file = File(_settingsPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = VideSettings.fromJson(json);
      }
    } catch (e) {
      // Use defaults on error
    }
    _loaded = true;
  }

  /// Save current settings to disk
  Future<void> save() async {
    try {
      final file = File(_settingsPath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_settings.toJson()),
      );
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Update settings
  Future<void> update(VideSettings newSettings) async {
    _settings = newSettings;
    await save();
  }

  /// Toggle code sommelier
  Future<void> setCodeSommelierEnabled(bool enabled) async {
    _settings = _settings.copyWith(codeSommelierEnabled: enabled);
    await save();
  }
}
