import 'dart:convert';
import 'dart:io';

/// Utility class for loading test fixtures
class FixtureLoader {
  static const String _fixturesPath = 'test/fixtures';

  /// Load a JSON file and return as Map
  static Map<String, dynamic> loadJson(String relativePath) {
    final file = File('$_fixturesPath/$relativePath');
    final content = file.readAsStringSync();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Load a JSONL file and return as list of lines
  static List<String> loadJsonl(String relativePath) {
    final file = File('$_fixturesPath/$relativePath');
    final content = file.readAsStringSync();
    return content.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  /// Load a JSONL file and parse each line as JSON
  static List<Map<String, dynamic>> loadJsonlParsed(String relativePath) {
    return loadJsonl(
      relativePath,
    ).map((line) => jsonDecode(line) as Map<String, dynamic>).toList();
  }

  /// Load a file as raw string
  static String loadRaw(String relativePath) {
    final file = File('$_fixturesPath/$relativePath');
    return file.readAsStringSync();
  }

  /// Create a stream from fixture file (line by line)
  static Stream<String> loadStream(String relativePath) async* {
    final lines = loadJsonl(relativePath);
    for (final line in lines) {
      yield line;
    }
  }

  // ===== Pre-built response fixtures =====

  static Map<String, dynamic> get textResponseJson => {
    'type': 'text',
    'content': 'Hello from Claude!',
    'id': 'msg_test_123',
  };

  static Map<String, dynamic> get toolUseResponseJson => {
    'type': 'assistant',
    'message': {
      'id': 'msg_test_456',
      'role': 'assistant',
      'content': [
        {
          'type': 'tool_use',
          'id': 'tool_test_789',
          'name': 'Read',
          'input': {'file_path': '/path/to/file.txt'},
        },
      ],
    },
  };

  static Map<String, dynamic> get toolResultResponseJson => {
    'type': 'user',
    'message': {
      'role': 'user',
      'content': [
        {
          'type': 'tool_result',
          'tool_use_id': 'tool_test_789',
          'content': 'File contents here',
        },
      ],
    },
  };

  static Map<String, dynamic> get completionResponseJson => {
    'type': 'result',
    'subtype': 'success',
    'uuid': 'result_test_123',
    'usage': {'input_tokens': 100, 'output_tokens': 50},
  };

  static Map<String, dynamic> get errorResponseJson => {
    'type': 'error',
    'error': 'Something went wrong',
    'details': 'More information here',
    'code': 'ERR_001',
  };

  static Map<String, dynamic> get metaResponseJson => {
    'type': 'system',
    'subtype': 'init',
    'conversation_id': 'conv_test_123',
    'metadata': {'version': '1.0'},
  };

  static Map<String, dynamic> get statusResponseJson => {
    'type': 'status',
    'status': 'processing',
    'message': 'Working on it...',
  };
}
