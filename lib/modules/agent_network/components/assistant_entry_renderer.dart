import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
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
    final configManager = context.read(videConfigManagerProvider);
    final showThinking = configManager.readGlobalSettings().showThinking;
    final children = <Component>[];
    var prevWasTool = false;

    for (final content in entry.content) {
      final widgets = switch (content) {
        ThinkingContent(:final text) when text.trim().isNotEmpty && showThinking => [
          Text(
            text.trim(),
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        TextContent(:final text, :final isContextWindowError) when text.isNotEmpty => [
          MarkdownText(text.trimRight(), styleSheet: theme.markdownStyleSheet),
          if (isContextWindowError)
            Container(
              padding: EdgeInsets.only(top: 1),
              child: Text(
                '💡 Tip: Type /compact to free up context space',
                style: TextStyle(color: theme.base.primary),
              ),
            ),
        ],
        ToolContent() when !content.isHidden => [_buildToolInvocation(content)],
        _ => <Component>[],
      };

      if (widgets.isEmpty) continue;

      final isCompactTool = content is ToolContent && content.toolName != 'Bash';

      // Add spacing between content blocks, but not between consecutive
      // compact tool calls so they group tightly. Bash always gets spacing
      // since it renders expanded terminal output.
      if (children.isNotEmpty && !(isCompactTool && prevWasTool)) {
        children.add(SizedBox(height: 1));
      }
      children.addAll(widgets);
      prevWasTool = isCompactTool;
    }

    // Show loading indicator if streaming with no content yet
    if (children.isEmpty && entry.isStreaming) {
      children.add(EnhancedLoadingIndicator());
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Component _buildToolInvocation(ToolContent content) {
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
    return ToolInvocationRouter(
      key: ValueKey(content.toolUseId),
      invocation: invocation,
      workingDirectory: workingDirectory,
      executionId: networkId,
      agentId: agentId,
    );
  }
}
