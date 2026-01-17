import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'vide_config_manager.dart';

/// PostHog analytics service for tracking product usage.
///
/// Uses the HTTP API directly for simplicity.
/// Events are sent immediately (no batching) using fire-and-forget pattern.
class PostHogService {
  static const String _apiKey =
      'phc_bZ79qWQHUVuLwkIV4nqIQH4L9XlvYUQqO7ui2aRXTdX';
  static const String _host = 'https://eu.i.posthog.com';

  static bool _initialized = false;
  static String? _distinctId;

  /// Initialize PostHog service.
  /// Loads or generates the anonymous distinct ID.
  /// Safe to call multiple times.
  ///
  /// The [configManager] parameter provides access to the config directory for storing the distinct ID.
  static Future<void> init(VideConfigManager configManager) async {
    if (_initialized) return;

    try {
      _distinctId = await _loadOrCreateDistinctId(configManager);
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
    final idFile = File('$configDir/posthog_distinct_id');

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
  /// Fire-and-forget - does not await the HTTP request.
  static void capture(String event, [Map<String, dynamic>? properties]) {
    if (!_initialized || _distinctId == null) return;

    // Fire and forget - don't await
    _sendEvent(event, properties);
  }

  /// Internal method to send event to PostHog.
  static Future<void> _sendEvent(
    String event,
    Map<String, dynamic>? properties,
  ) async {
    try {
      final body = jsonEncode({
        'api_key': _apiKey,
        'event': event,
        'distinct_id': _distinctId,
        'properties': {'\$lib': 'vide-dart', ...?properties},
      });

      await http.post(
        Uri.parse('$_host/batch/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      // Silently ignore errors - analytics should never impact the app
    }
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
    capture('error_occurred', {'error_type': errorType});
  }
}
