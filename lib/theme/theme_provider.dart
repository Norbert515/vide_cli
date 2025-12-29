import 'package:nocterm/nocterm.dart';
import 'package:riverpod/riverpod.dart';
import 'package:vide_cli/modules/setup/theme_selector.dart';
import 'package:vide_core/vide_core.dart';

/// Provider for the current theme setting from config.
/// Returns null for auto-detect, or a theme ID string.
final themeSettingProvider = StateProvider<String?>((ref) {
  final configManager = ref.read(videConfigManagerProvider);
  return configManager.getTheme();
});

/// Provider that returns the TuiThemeData for the current theme setting.
/// Returns null if auto-detect is enabled.
final explicitThemeProvider = Provider<TuiThemeData?>((ref) {
  final themeId = ref.watch(themeSettingProvider);
  return ThemeOption.getThemeData(themeId);
});

/// Updates the theme setting and persists it to config.
void setTheme(ProviderContainer container, String? themeId) {
  final configManager = container.read(videConfigManagerProvider);
  configManager.setTheme(themeId);
  container.read(themeSettingProvider.notifier).state = themeId;
}

/// Provider for controlling whether thinking tokens are displayed.
/// Toggle with Ctrl+O shortcut.
final showThinkingProvider = StateProvider<bool>((ref) {
  final configManager = ref.read(videConfigManagerProvider);
  return configManager.getShowThinking();
});

/// Toggles the showThinking setting and persists it to config.
void toggleShowThinking(ProviderContainer container) {
  final configManager = container.read(videConfigManagerProvider);
  final current = container.read(showThinkingProvider);
  final newValue = !current;
  configManager.setShowThinking(newValue);
  container.read(showThinkingProvider.notifier).state = newValue;
}
