import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Service that fetches pre-generated facts from a curated pipeline.
/// Facts are fetched once at startup and randomly selected at runtime.
class FactSourceService {
  // Singleton pattern
  static final FactSourceService instance = FactSourceService._();
  FactSourceService._();

  static const _factsUrl =
      'https://storage.googleapis.com/atelier-cms.firebasestorage.app/facts/latest.json';

  // List of pre-generated facts
  final List<String> _facts = [];

  // Track which facts have been shown to avoid repeats within a session
  final Set<int> _shownIndices = {};

  // Random generator
  final _random = Random();

  // Whether initial fetch has completed
  bool _initialized = false;

  /// Whether the service has been initialized
  bool get initialized => _initialized;

  void _debugLog(String message) {
    if (Platform.environment['VIDE_DEBUG_HAIKU'] == '1') {
      final timestamp = DateTime.now().toIso8601String();
      File('/tmp/vide_haiku.log').writeAsStringSync(
        '[$timestamp] [FactSourceService] $message\n',
        mode: FileMode.append,
      );
    }
  }

  /// Initialize by fetching facts from the curated pipeline.
  Future<void> initialize() async {
    if (_initialized) return;
    _debugLog('initialize() called');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse(_factsUrl));
      final response = await request.close();
      _debugLog('HTTP status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;

        // Extract facts from the JSON
        final factsList = data['facts'] as List<dynamic>? ?? [];
        for (final fact in factsList) {
          final text = fact['text'] as String?;
          if (text != null && text.isNotEmpty) {
            _facts.add(text);
          }
        }
        _debugLog('Loaded ${_facts.length} facts');
      }
    } catch (e) {
      _debugLog('Error: $e');
      // Graceful degradation - facts list stays empty
    }

    _initialized = true;
  }

  /// Get a random fact. Returns null if no facts available.
  /// Tracks shown facts to avoid repeats within a session.
  String? getRandomFact() {
    _debugLog('getRandomFact() called, facts.length=${_facts.length}, initialized=$_initialized');
    if (!_initialized || _facts.isEmpty) return null;

    // Reset shown indices if we've shown all facts
    if (_shownIndices.length >= _facts.length) {
      _shownIndices.clear();
    }

    // Find an unshown fact
    int index;
    do {
      index = _random.nextInt(_facts.length);
    } while (_shownIndices.contains(index) && _shownIndices.length < _facts.length);

    _shownIndices.add(index);
    return _facts[index];
  }

  /// Get next fact context (for compatibility with existing code)
  /// Now just returns a random fact directly instead of source material.
  String? getNextFactContext() {
    return getRandomFact();
  }
}
