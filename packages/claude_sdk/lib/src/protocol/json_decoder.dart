import 'dart:convert';
import '../models/response.dart';

class JsonDecoder {
  final StringBuffer _buffer = StringBuffer();

  JsonDecoder();

  Stream<ClaudeResponse> decodeStream(Stream<String> stream) async* {
    await for (final chunk in stream) {
      yield* _processChunk(chunk);
    }
  }

  Stream<ClaudeResponse> _processChunk(String chunk) async* {
    _buffer.write(chunk);
    final lines = _buffer.toString().split('\n');

    // Keep the last incomplete line in the buffer
    if (lines.isNotEmpty && !chunk.endsWith('\n')) {
      _buffer.clear();
      _buffer.write(lines.last);
      lines.removeLast();
    } else {
      _buffer.clear();
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        // Use fromJsonMultiple to handle interleaved assistant content
        final responses = ClaudeResponse.fromJsonMultiple(json);
        for (final response in responses) {
          yield response;
        }
      } catch (e) {
        // Try to handle partial JSON or malformed responses
        if (line.contains('"type"') || line.contains('"content"')) {
          yield ErrorResponse(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            error: 'Failed to parse response',
            details: 'Raw: $line, Error: $e',
          );
        }
        // Otherwise, might be debug output - ignore
      }
    }
  }

  ClaudeResponse? decodeSingle(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return ClaudeResponse.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  /// Decodes a JSON string and returns multiple responses if the message
  /// contains interleaved content (text + tool_use + text).
  List<ClaudeResponse> decodeMultiple(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return ClaudeResponse.fromJsonMultiple(decoded);
    } catch (e) {
      return [];
    }
  }
}
