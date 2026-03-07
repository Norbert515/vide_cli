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

/// Entry originated from a user message.
final class UserMessageSource extends ChannelEntrySource {
  final int eventIndex;
  const UserMessageSource(this.eventIndex);
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
  /// 1. User MessageEvents (all user messages shown in channel)
  /// 2. Assistant MessageEvents whose accumulated text starts with @mention
  /// 3. sendMessageToAgent ToolUseEvents
  ///
  /// Returns entries in event arrival order (oldest first).
  static List<ChannelTimelineEntry> project(List<VideEvent> events) {
    final entries = <ChannelTimelineEntry>[];

    // Track accumulated text per (agentId, eventId) for streaming messages.
    // Key: "$agentId:$eventId"
    final accumulatedText = <String, String>{};
    // Track the last event index for each accumulated message.
    final lastEventIndex = <String, int>{};
    // Track accumulated user message text (same streaming pattern).
    final userAccumulatedText = <String, String>{};
    final userLastEventIndex = <String, int>{};

    for (int i = 0; i < events.length; i++) {
      final event = events[i];

      switch (event) {
        case MessageEvent e when e.role == MessageRole.user:
          final key = '${e.agentId}:${e.eventId}';
          userAccumulatedText[key] =
              (userAccumulatedText[key] ?? '') + e.content;
          userLastEventIndex[key] = i;

          if (!e.isPartial) {
            final fullText = userAccumulatedText[key]!;
            // Skip empty messages and system-like messages (e.g. "[Request interrupted]")
            if (fullText.isNotEmpty &&
                !(fullText.startsWith('[') && fullText.endsWith(']'))) {
              entries.add(ChannelTimelineEntry(
                senderAgentId: e.agentId,
                senderAgentName: 'You',
                senderAgentType: 'user',
                target: AgentMention(e.agentId),
                content: fullText,
                timestamp: e.timestamp,
                source: UserMessageSource(userLastEventIndex[key]!),
              ));
            }
            userAccumulatedText.remove(key);
            userLastEventIndex.remove(key);
          }

        case MessageEvent e when e.role == MessageRole.assistant:
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

          final target = switch (targetAgentId) {
            '@everyone' => const EveryoneMention(),
            _ => AgentMention(targetAgentId),
          };

          entries.add(ChannelTimelineEntry(
            senderAgentId: e.agentId,
            senderAgentName: e.agentName,
            senderAgentType: e.agentType,
            target: target,
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
