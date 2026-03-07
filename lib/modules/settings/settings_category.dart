import 'package:vide_core/vide_core.dart' show videVersion;

/// Settings category enum for navigation.
enum SettingsCategory {
  general('General'),
  team('Team'),
  appearance('Appearance'),
  daemon('Daemon'),
  debug('Debug'),
  about('About');

  const SettingsCategory(this.label);
  final String label;

  /// Categories visible in the current build.
  /// Debug is only shown in dev builds (version contains 'dev').
  static List<SettingsCategory> get visible => videVersion.contains('dev')
      ? values
      : values.where((c) => c != debug).toList();
}
