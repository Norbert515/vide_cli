import 'dart:convert';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';

import '../models/conversation_metadata.dart';
import '../models/raw_event.dart';

/// Service for loading raw events from Claude Code conversation JSONL files.
///
/// Unlike ConversationLoader from claude_sdk, this service does NOT filter
/// any events. It loads everything for inspection purposes.
class ConversationLoadingService {
  final String? _claudeDirOverride;

  ConversationLoadingService({String? claudeDir}) : _claudeDirOverride = claudeDir;

  /// Get the Claude directory path.
  String get claudeDir {
    if (_claudeDirOverride != null) return _claudeDirOverride;
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw StateError('Could not determine home directory');
    }
    return '$home/.claude';
  }

  /// Load all events from a conversation without any filtering.
  ///
  /// Returns every line in the JSONL file as a RawEvent, including:
  /// - Meta messages (isMeta: true)
  /// - Unknown response types
  /// - Status and completion messages
  /// - Malformed JSON (with parse errors)
  Future<List<RawEvent>> loadConversation(ConversationMetadata metadata) async {
    return loadConversationByPath(
      metadata.sessionId,
      metadata.encodedProjectPath,
    );
  }

  /// Load all events from a conversation by session ID and encoded project path.
  Future<List<RawEvent>> loadConversationByPath(
    String sessionId,
    String encodedProjectPath,
  ) async {
    final filePath = '$claudeDir/projects/$encodedProjectPath/$sessionId.jsonl';
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Conversation not found', filePath);
    }

    final lines = await file.readAsLines();
    return _parseLines(lines);
  }

  /// Load events from a file path directly.
  Future<List<RawEvent>> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final lines = await file.readAsLines();
    return _parseLines(lines);
  }

  /// Stream events as they're parsed (for large files).
  Stream<RawEvent> streamConversation(ConversationMetadata metadata) async* {
    final filePath = '$claudeDir/projects/${metadata.encodedProjectPath}/${metadata.sessionId}.jsonl';
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Conversation not found', filePath);
    }

    final lines = await file.readAsLines();
    int lineNumber = 0;

    for (final line in lines) {
      lineNumber++;
      if (line.trim().isEmpty) continue;

      yield _parseLine(line, lineNumber);
    }
  }

  /// Parse all lines into RawEvents.
  List<RawEvent> _parseLines(List<String> lines) {
    final events = <RawEvent>[];
    int lineNumber = 0;

    for (final line in lines) {
      lineNumber++;
      if (line.trim().isEmpty) continue;

      events.add(_parseLine(line, lineNumber));
    }

    return events;
  }

  /// Parse a single line into a RawEvent.
  RawEvent _parseLine(String line, int lineNumber) {
    Map<String, dynamic> rawJson;
    ClaudeResponse? parsed;
    String? parseError;

    try {
      rawJson = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      // Even malformed JSON gets recorded
      return RawEvent(
        lineNumber: lineNumber,
        rawJson: {
          '_parseError': 'Invalid JSON',
          '_errorMessage': e.toString(),
          '_rawLine': line.length > 1000 ? '${line.substring(0, 1000)}...' : line,
        },
        parseError: 'Invalid JSON: $e',
      );
    }

    // Attempt to parse using claude_sdk's ClaudeResponse
    try {
      parsed = ClaudeResponse.fromJson(rawJson);
    } catch (e) {
      parseError = 'ClaudeResponse parse error: $e';
    }

    return RawEvent(
      lineNumber: lineNumber,
      rawJson: rawJson,
      parsedResponse: parsed,
      parseError: parseError,
    );
  }

  /// Get statistics about a conversation's events.
  Future<ConversationStats> getConversationStats(
    ConversationMetadata metadata,
  ) async {
    final events = await loadConversation(metadata);
    return ConversationStats.fromEvents(events);
  }
}

/// Statistics about a conversation's events.
class ConversationStats {
  final int totalEvents;
  final int userMessages;
  final int assistantMessages;
  final int toolUses;
  final int toolResults;
  final int errors;
  final int metaMessages;
  final int unknownTypes;
  final int parseErrors;
  final Map<String, int> typeBreakdown;

  const ConversationStats({
    required this.totalEvents,
    required this.userMessages,
    required this.assistantMessages,
    required this.toolUses,
    required this.toolResults,
    required this.errors,
    required this.metaMessages,
    required this.unknownTypes,
    required this.parseErrors,
    required this.typeBreakdown,
  });

  factory ConversationStats.fromEvents(List<RawEvent> events) {
    int userMessages = 0;
    int assistantMessages = 0;
    int toolUses = 0;
    int toolResults = 0;
    int errors = 0;
    int metaMessages = 0;
    int unknownTypes = 0;
    int parseErrors = 0;
    final typeBreakdown = <String, int>{};

    for (final event in events) {
      // Count by raw type
      final rawType = event.rawType;
      typeBreakdown[rawType] = (typeBreakdown[rawType] ?? 0) + 1;

      // Count meta messages
      if (event.isMeta) {
        metaMessages++;
      }

      // Count parse errors
      if (event.hasParseError) {
        parseErrors++;
      }

      // Count by parsed type
      final response = event.parsedResponse;
      if (response == null) {
        if (!event.hasParseError) {
          unknownTypes++;
        }
      } else {
        switch (response) {
          case UserMessageResponse _:
            userMessages++;
          case TextResponse _:
            assistantMessages++;
          case ToolUseResponse _:
            toolUses++;
          case ToolResultResponse _:
            toolResults++;
          case ErrorResponse _:
            errors++;
          case UnknownResponse _:
            unknownTypes++;
          default:
            break;
        }
      }
    }

    return ConversationStats(
      totalEvents: events.length,
      userMessages: userMessages,
      assistantMessages: assistantMessages,
      toolUses: toolUses,
      toolResults: toolResults,
      errors: errors,
      metaMessages: metaMessages,
      unknownTypes: unknownTypes,
      parseErrors: parseErrors,
      typeBreakdown: typeBreakdown,
    );
  }
}
