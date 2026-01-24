import 'dart:io';

import 'package:bashboard/bashboard.dart';
import 'package:uuid/uuid.dart';
import 'vide_config_manager.dart';

/// Bashboard analytics service for tracking product usage.
///
/// Wraps the Bashboard SDK for CLI analytics.
/// Events are batched and sent periodically.
class BashboardService {
  static const String _apiKey = 'bb_O2vxR6phes2iiskhnbnzwtkjk825JfwA';

  static bool _initialized = false;

  /// Initialize Bashboard service.
  /// Loads or generates the anonymous distinct ID.
  /// Safe to call multiple times.
  ///
  /// The [configManager] parameter provides access to the config directory for storing the distinct ID.
  static Future<void> init(VideConfigManager configManager) async {
    if (_initialized) return;

    try {
      final distinctId = await _loadOrCreateDistinctId(configManager);

      Bashboard.init(
        apiKey: _apiKey,
        config: BashboardConfig(
          cliName: 'vide',
          cliVersion: '1.0.0',
          respectDoNotTrack: true,
          // Disable disk persistence to send events during current session
          // (otherwise events are queued to disk and sent on next launch)
          persistToDisk: false,
          // Flush every 10 seconds
          flushInterval: Duration(seconds: 10),
        ),
      );

      // Identify the user with their anonymous ID
      Bashboard.identify(distinctId);

      // Start a session
      Bashboard.startSession();

      _initialized = true;
    } catch (e) {
      // Fail silently - analytics should never crash the app
      _initialized = false;
    }
  }

  /// Load existing distinct ID or create a new one.
  static Future<String> _loadOrCreateDistinctId(
    VideConfigManager configManager,
  ) async {
    final configDir = configManager.configRoot;
    final idFile = File('$configDir/bashboard_distinct_id');

    if (await idFile.exists()) {
      final id = await idFile.readAsString();
      if (id.trim().isNotEmpty) {
        return id.trim();
      }
    }

    // Generate new anonymous ID
    final newId = const Uuid().v4();

    // Persist it
    try {
      await idFile.parent.create(recursive: true);
      await idFile.writeAsString(newId);
    } catch (e) {
      // Continue even if we can't persist - just use the generated ID
    }

    return newId;
  }

  /// Capture an event with optional properties.
  static void capture(String event, [Map<String, dynamic>? properties]) {
    if (!_initialized) return;

    Bashboard.track(event, properties: properties ?? {});
  }

  /// Flush pending events. Call before app exit.
  static Future<void> flush() async {
    if (!_initialized) return;

    await Bashboard.flush();
  }

  // --- Helper methods for common events ---

  /// Track app launch
  static void appStarted() {
    capture('app_started');
  }

  /// Track new conversation starting
  static void conversationStarted() {
    capture('conversation_started');
  }

  /// Track when an agent is spawned
  static void agentSpawned(String agentType) {
    capture('agent_spawned', {'agent_type': agentType});
  }

  /// Track errors for product analytics (alongside Sentry)
  static void errorOccurred(String errorType) {
    Bashboard.trackError(
      'error_occurred',
      message: errorType,
    );
  }
}
