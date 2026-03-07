import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/theme/theme.dart';

/// Renders the channel timeline: a chronological list of cross-agent
/// @mention messages and sendMessageToAgent tool invocations.
class ChannelView extends StatefulComponent {
  final VideSession session;
  final List<VideAgent> agents;
  final bool contentFocused;
  final VoidCallback focusLeftSidebar;
  final VoidCallback focusRightSidebar;

  const ChannelView({
    required this.session,
    required this.agents,
    required this.contentFocused,
    required this.focusLeftSidebar,
    required this.focusRightSidebar,
    super.key,
  });

  @override
  State<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<ChannelView> {
  final _scrollController = AutoScrollController();
  List<ChannelTimelineEntry> _entries = const [];
  StreamSubscription<VideEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _entries = ChannelTimelineProjector.project(
      component.session.eventHistory,
    );
    _eventSub = component.session.events.listen((event) {
      if (!mounted) return;
      if (event is MessageEvent && event.isPartial) return;
      if (event is! MessageEvent && event is! ToolUseEvent) return;
      final updated = ChannelTimelineProjector.project(
        component.session.eventHistory,
      );
      if (updated.length != _entries.length) {
        setState(() => _entries = updated);
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  String _resolveAgentName(String agentId) {
    // Check live agents first.
    for (final agent in component.agents) {
      if (agent.id == agentId) return '@${agent.name}';
    }
    // Fall back to names from event history (survives agent termination).
    for (final event in component.session.eventHistory.reversed) {
      if (event.agentId == agentId && event.agentName != null) {
        return '@${event.agentName}';
      }
    }
    final short = agentId.length > 8 ? agentId.substring(0, 8) : agentId;
    return '@$short';
  }

  String _resolveTarget(MentionTarget target) {
    return switch (target) {
      UserMention() => '@user',
      EveryoneMention() => '@everyone',
      AgentMention(agentId: final id) => _resolveAgentName(id),
      NoMention() => '',
    };
  }

  void _handleSendMessage(AgentMessage message) {
    final mainAgent = component.agents.firstOrNull;
    if (mainAgent == null) return;
    component.session.sendMessage(message, agentId: mainAgent.id);
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final hasAgents = component.agents.isNotEmpty;

    final Component timeline;
    if (_entries.isEmpty) {
      timeline = Expanded(
        child: Center(
          child: Text(
            'No channel messages yet',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ),
      );
    } else {
      timeline = Expanded(
        child: SelectionArea(
          onSelectionCompleted: ClipboardManager.copy,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: EdgeInsets.all(1),
            lazy: true,
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[_entries.length - 1 - index];
              return _buildEntryRow(entry, theme);
            },
          ),
        ),
      );
    }

    return Expanded(
      child: Focusable(
        focused: component.contentFocused,
        onKeyEvent: (event) {
          if (event.logicalKey == LogicalKey.arrowLeft) {
            component.focusLeftSidebar();
            return true;
          }
          if (event.logicalKey == LogicalKey.arrowRight) {
            component.focusRightSidebar();
            return true;
          }
          return false;
        },
        child: Column(
          children: [
            timeline,
            AttachmentTextField(
              focused: component.contentFocused,
              enabled: hasAgents,
              placeholder: hasAgents
                  ? 'Message #channel (sends to main agent)'
                  : 'No agents available',
              onSubmit: _handleSendMessage,
              onLeftEdge: component.focusLeftSidebar,
              onRightEdge: component.focusRightSidebar,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Component _buildEntryRow(ChannelTimelineEntry entry, VideThemeData theme) {
    final senderName = entry.senderAgentName ?? entry.senderAgentType;
    final targetName = _resolveTarget(entry.target);
    final dimColor = theme.base.onSurface.withOpacity(TextOpacity.tertiary);
    final isUser = entry.senderAgentType == 'user';

    // Show first 8 lines as preview
    final lines = entry.content.split('\n');
    final preview = lines.length > 8
        ? '${lines.take(8).join('\n')}...'
        : entry.content;

    final body = Padding(
      padding: EdgeInsets.only(left: 2),
      child: MarkdownText(
        preview.trimRight(),
        styleSheet: theme.markdownStyleSheet,
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: sender → target                        HH:mm
        Row(
          children: [
            Text(
              senderName,
              style: TextStyle(
                color: theme.base.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (targetName.isNotEmpty)
              Text(
                '  \u2192  $targetName',
                style: TextStyle(color: dimColor),
              ),
            Expanded(child: SizedBox()),
            Text(
              _formatTime(entry.timestamp),
              style: TextStyle(color: dimColor),
            ),
          ],
        ),
        body,
      ],
    );

    if (isUser) {
      return Padding(
        padding: EdgeInsets.only(bottom: 1),
        child: Container(
          decoration: BoxDecoration(
            color: theme.base.primary.withOpacity(0.05),
          ),
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: content,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 1),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 1),
        child: content,
      ),
    );
  }
}
