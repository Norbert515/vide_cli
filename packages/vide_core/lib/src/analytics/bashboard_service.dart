import 'dart:io';

import 'package:bashboard/bashboard.dart';
import 'package:uuid/uuid.dart';
import '../../version.dart';
import '../configuration/vide_config_manager.dart';

/// Bashboard analytics service for tracking product usage.
///
/// Wraps the Bashboard SDK for CLI analytics.
/// Events are batched and sent periodically.
class BashboardService {
  static const String _apiKey = 'bb_Ea9k4WNNxcATHZi4eUeZ2pZuGrIHRkTx';

  static bool _initialized = false;
  static bool _initializing = false;

  /// Initialize Bashboard service (non-blocking).
  /// Starts async initialization in the background and tracks app_started when ready.
  /// Safe to call multiple times.
  ///
  /// The [configManager] parameter provides access to the config directory for storing the distinct ID.
  /// If [telemetryEnabled] is false, initialization is skipped entirely.
  static void init(
    VideConfigManager configManager, {
    bool telemetryEnabled = true,
  }) {
    if (!telemetryEnabled) return;
    if (_initialized || _initializing) return;
    _initializing = true;

    // Fire-and-forget async initialization
    Future<void>(() async {
      try {
        final distinctId = await _loadOrCreateDistinctId(configManager);

        Bashboard.init(
          apiKey: _apiKey,
          config: BashboardConfig(
            cliName: 'vide',
            cliVersion: videVersion,
            respectDoNotTrack: true,
            // Flush every 10 seconds
            flushInterval: Duration(seconds: 10),
          ),
        );

        // Identify the user with their anonymous ID
        Bashboard.identify(distinctId);

        // Start a session
        Bashboard.startSession();

        _initialized = true;

        // Clean up legacy PostHog distinct ID file
        _cleanupLegacyPosthog(configManager);

        // Track app started now that we're initialized
        appStarted();
      } catch (e) {
        // Fail silently - analytics should never crash the app
        _initialized = false;
      } finally {
        _initializing = false;
      }
    });
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

  /// Delete the legacy PostHog distinct ID file if it exists.
  static void _cleanupLegacyPosthog(VideConfigManager configManager) {
    try {
      final file = File('${configManager.configRoot}/posthog_distinct_id');
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Best-effort cleanup
    }
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

  /// Track app launch with platform metadata.
  static void appStarted() {
    capture('app_started', {
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'dart_version': Platform.version.split(' ').first,
    });
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
    Bashboard.trackError('error_occurred', message: errorType);
  }
}
