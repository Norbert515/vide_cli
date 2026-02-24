import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/tool_invocation_router.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Renders an assistant conversation entry: thinking blocks, text (markdown),
/// tool invocations, and a loading indicator while streaming.
class AssistantEntryRenderer extends StatelessComponent {
  final ConversationEntry entry;
  final String networkId;
  final String agentId;
  final String workingDirectory;

  const AssistantEntryRenderer({
    required this.entry,
    required this.networkId,
    required this.agentId,
    required this.workingDirectory,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final widgets = <Component>[];
    final pendingTools = <Component>[];

    void flushToolGroup() {
      if (pendingTools.isEmpty) return;
      widgets.addAll(pendingTools);
      pendingTools.clear();
    }

    for (final content in entry.content) {
      if (content is ThinkingContent) {
        flushToolGroup();
        if (content.text.trim().isNotEmpty) {
          widgets.add(
            Text(
              content.text.trim(),
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
      } else if (content is TextContent) {
        flushToolGroup();
        if (content.text.isNotEmpty) {
          widgets.add(MarkdownText(content.text, styleSheet: theme.markdownStyleSheet));

          if (content.isContextWindowError) {
            widgets.add(
              Container(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  '💡 Tip: Type /compact to free up context space',
                  style: TextStyle(color: theme.base.primary),
                ),
              ),
            );
          }
        }
      } else if (content is ToolContent) {
        final now = DateTime.now();
        final invocation = AgentToolInvocation.createTyped(
          toolCall: AgentToolUseResponse(
            id: content.toolUseId,
            timestamp: now,
            toolName: content.toolName,
            parameters: content.toolInput,
            toolUseId: content.toolUseId,
          ),
          toolResult: content.result != null
              ? AgentToolResultResponse(
                  id: content.toolUseId,
                  timestamp: now,
                  toolUseId: content.toolUseId,
                  content: content.result!,
                  isError: content.isError,
                )
              : null,
        );

        pendingTools.add(
          ToolInvocationRouter(
            key: ValueKey(content.toolUseId),
            invocation: invocation,
            workingDirectory: workingDirectory,
            executionId: networkId,
            agentId: agentId,
          ),
        );
      }
    }
    flushToolGroup();

    // Show loading indicator if streaming with no content yet
    if (widgets.isEmpty && entry.isStreaming) {
      widgets.add(EnhancedLoadingIndicator(agentId: agentId));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
