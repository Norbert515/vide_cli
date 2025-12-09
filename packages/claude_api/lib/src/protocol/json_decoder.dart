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
        yield ClaudeResponse.fromJson(json);
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
}
