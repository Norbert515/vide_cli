import 'dart:convert';

import 'codex_event.dart';

/// Parses raw JSONL lines from `codex exec --json` stdout into [CodexEvent]s.
class CodexEventParser {
  /// Parse a single JSON line into a [CodexEvent].
  /// Returns null if the line is empty or cannot be parsed.
  CodexEvent? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      return CodexEvent.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Parse a chunk of text that may contain multiple JSONL lines.
  List<CodexEvent> parseChunk(String chunk) {
    final events = <CodexEvent>[];
    for (final line in chunk.split('\n')) {
      final event = parseLine(line);
      if (event != null) {
        events.add(event);
      }
    }
    return events;
  }
}
