import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// The current theme mode override.
///
/// This is a global notifier that the DebugOverlayWrapper listens to.
/// When the value changes, the UI rebuilds with the new theme mode.
final ValueNotifier<ThemeModeOverride> themeModeNotifier =
    ValueNotifier(ThemeModeOverride.system);

/// Theme mode override values
enum ThemeModeOverride {
  /// Use system theme (no override)
  system,

  /// Force light theme
  light,

  /// Force dark theme
  dark,
}

/// Parse a string to ThemeModeOverride
ThemeModeOverride? _parseThemeMode(String? value) {
  if (value == null) return null;
  switch (value.toLowerCase()) {
    case 'light':
      return ThemeModeOverride.light;
    case 'dark':
      return ThemeModeOverride.dark;
    case 'system':
      return ThemeModeOverride.system;
    default:
      return null;
  }
}

/// Convert ThemeModeOverride to string
String _themeModeToString(ThemeModeOverride mode) {
  switch (mode) {
    case ThemeModeOverride.light:
      return 'light';
    case ThemeModeOverride.dark:
      return 'dark';
    case ThemeModeOverride.system:
      return 'system';
  }
}

/// Registers the theme switching service extensions
///
/// This extension allows switching between light, dark, and system theme modes
/// by wrapping the app with a MediaQuery override.
void registerThemeExtension() {
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.setThemeMode',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.setThemeMode',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] setThemeMode extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final modeStr = parameters['mode'];

        if (modeStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameter: mode',
          );
        }

        final mode = _parseThemeMode(modeStr);

        if (mode == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid mode: "$modeStr". Must be one of: light, dark, system',
          );
        }

        // Update the theme mode notifier
        themeModeNotifier.value = mode;

        print(
            '✅ [RuntimeAiDevTools] Theme mode set to ${_themeModeToString(mode)}');

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'mode': _themeModeToString(mode),
          }),
        );
      } catch (e, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to set theme mode: $e\n$stackTrace',
        );
      }
    },
  );

  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getThemeMode',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getThemeMode',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getThemeMode extension called');

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'mode': _themeModeToString(themeModeNotifier.value),
        }),
      );
    },
  );
}
