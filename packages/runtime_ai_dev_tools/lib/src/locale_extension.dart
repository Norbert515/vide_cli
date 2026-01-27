import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// The current locale override.
///
/// This is a global notifier that the DebugOverlayWrapper listens to.
/// When the value changes, the UI rebuilds with the new locale.
/// A null value means use the system locale.
final ValueNotifier<ui.Locale?> localeNotifier = ValueNotifier(null);

/// Parse a locale string like "en-US" or "ja" into a Locale
ui.Locale? _parseLocale(String? value) {
  if (value == null || value.isEmpty) return null;

  // Handle formats like "en-US", "en_US", "en"
  final parts = value.split(RegExp(r'[-_]'));
  if (parts.isEmpty) return null;

  final languageCode = parts[0].toLowerCase();
  final countryCode = parts.length > 1 ? parts[1].toUpperCase() : null;

  return ui.Locale(languageCode, countryCode);
}

/// Convert a Locale to string format
String _localeToString(ui.Locale locale) {
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}-${locale.countryCode}';
  }
  return locale.languageCode;
}

/// Registers the locale switching service extensions
///
/// This extension allows switching the app's locale for testing
/// localization without changing system settings.
void registerLocaleExtension() {
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.setLocale',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.setLocale',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] setLocale extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final languageCode = parameters['languageCode'];
        final countryCode = parameters['countryCode'];
        final localeString = parameters['locale'];

        ui.Locale? locale;

        // Support both "locale" parameter (e.g., "en-US") and separate parameters
        if (localeString != null && localeString.isNotEmpty) {
          locale = _parseLocale(localeString);
          if (locale == null) {
            return developer.ServiceExtensionResponse.error(
              developer.ServiceExtensionResponse.invalidParams,
              'Invalid locale format: "$localeString". Use format like "en-US" or "ja"',
            );
          }
        } else if (languageCode != null && languageCode.isNotEmpty) {
          locale = ui.Locale(
            languageCode.toLowerCase(),
            countryCode?.toUpperCase(),
          );
        } else {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameter: locale or languageCode',
          );
        }

        // Update the locale notifier
        localeNotifier.value = locale;

        print('✅ [RuntimeAiDevTools] Locale set to ${_localeToString(locale)}');

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'locale': _localeToString(locale),
            'languageCode': locale.languageCode,
            'countryCode': locale.countryCode,
          }),
        );
      } catch (e, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to set locale: $e\n$stackTrace',
        );
      }
    },
  );

  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getLocale',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getLocale',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getLocale extension called');

      final locale = localeNotifier.value;

      if (locale == null) {
        // Return the system locale when no override is set
        final systemLocale = ui.PlatformDispatcher.instance.locale;
        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'locale': _localeToString(systemLocale),
            'languageCode': systemLocale.languageCode,
            'countryCode': systemLocale.countryCode,
            'isOverride': false,
          }),
        );
      }

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'locale': _localeToString(locale),
          'languageCode': locale.languageCode,
          'countryCode': locale.countryCode,
          'isOverride': true,
        }),
      );
    },
  );

  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.resetLocale',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.resetLocale',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] resetLocale extension called');

      // Reset to system locale
      localeNotifier.value = null;

      print('✅ [RuntimeAiDevTools] Locale reset to system default');

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'message': 'Locale reset to system default',
        }),
      );
    },
  );
}
