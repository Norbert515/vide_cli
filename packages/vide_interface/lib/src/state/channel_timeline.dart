/// Channel timeline projection from event history.
library;

import '../events/vide_event.dart';
import '../models/enums.dart';
import '../utils/mention_parser.dart';

/// Source of a channel entry.
sealed class ChannelEntrySource {
  const ChannelEntrySource();
}

/// Entry originated from an assistant message with an @mention prefix.
final class AssistantMentionSource extends ChannelEntrySource {
  /// Index of the final (non-partial) MessageEvent in the event list.
  final int eventIndex;
  const AssistantMentionSource(this.eventIndex);
}

/// Entry originated from a sendMessageToAgent tool invocation.
final class ToolMessageSource extends ChannelEntrySource {
  final String toolUseId;
  const ToolMessageSource(this.toolUseId);
}

/// A single entry in the channel timeline.
class ChannelTimelineEntry {
  final String senderAgentId;
  final String? senderAgentName;
  final String senderAgentType;
  final MentionTarget target;
  final String content;
  final DateTime timestamp;
  final ChannelEntrySource source;

  const ChannelTimelineEntry({
    required this.senderAgentId,
    this.senderAgentName,
    required this.senderAgentType,
    required this.target,
    required this.content,
    required this.timestamp,
    required this.source,
  });
}

/// Projects channel entries from raw event history.
abstract final class ChannelTimelineProjector {
  static const _sendMessageToolName = 'mcp__vide-agent__sendMessageToAgent';

  /// Scan event history and extract channel-relevant entries.
  ///
  /// Includes:
  /// 1. Assistant MessageEvents whose accumulated text starts with @mention
  /// 2. sendMessageToAgent ToolUseEvents
  ///
  /// Returns entries sorted by timestamp (oldest first).
  static List<ChannelTimelineEntry> project(List<VideEvent> events) {
    final entries = <ChannelTimelineEntry>[];

    // Track accumulated text per (agentId, eventId) for streaming messages.
    // Key: "$agentId:$eventId"
    final accumulatedText = <String, String>{};
    // Track the last event index for each accumulated message.
    final lastEventIndex = <String, int>{};

    for (int i = 0; i < events.length; i++) {
      final event = events[i];

      switch (event) {
        case MessageEvent e:
          if (e.role != MessageRole.assistant) continue;

          final key = '${e.agentId}:${e.eventId}';
          accumulatedText[key] = (accumulatedText[key] ?? '') + e.content;
          lastEventIndex[key] = i;

          if (!e.isPartial) {
            final fullText = accumulatedText[key]!;
            final result = MentionParser.parse(fullText);
            if (result.target is! NoMention) {
              entries.add(ChannelTimelineEntry(
                senderAgentId: e.agentId,
                senderAgentName: e.agentName,
                senderAgentType: e.agentType,
                target: result.target,
                content: result.body,
                timestamp: e.timestamp,
                source: AssistantMentionSource(lastEventIndex[key]!),
              ));
            }
            accumulatedText.remove(key);
            lastEventIndex.remove(key);
          }

        case ToolUseEvent e:
          if (e.toolName != _sendMessageToolName) continue;
          final targetAgentId = e.toolInput['targetAgentId'] as String?;
          final message = e.toolInput['message'] as String?;
          if (targetAgentId == null || message == null) continue;

          entries.add(ChannelTimelineEntry(
            senderAgentId: e.agentId,
            senderAgentName: e.agentName,
            senderAgentType: e.agentType,
            target: AgentMention(targetAgentId),
            content: message,
            timestamp: e.timestamp,
            source: ToolMessageSource(e.toolUseId),
          ));

        default:
          continue;
      }
    }

    return entries;
  }
}
