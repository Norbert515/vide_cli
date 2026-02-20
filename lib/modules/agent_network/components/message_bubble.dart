import 'package:nocterm/nocterm.dart';
import 'package:claude_sdk/claude_sdk.dart' hide MessageRole;
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/tool_invocation_router.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Renders a single conversation entry (user or assistant message).
class MessageBubble extends StatelessComponent {
  final ConversationEntry entry;
  final String networkId;
  final String agentId;
  final String workingDirectory;

  /// Locally tracked attachments keyed by message text, used as fallback
  /// when [AttachmentContent] is not present in the entry.
  final Map<String, List<VideAttachment>> sentAttachments;

  const MessageBubble({
    required this.entry,
    required this.networkId,
    required this.agentId,
    required this.workingDirectory,
    this.sentAttachments = const {},
    super.key,
  });

  /// Returns true if an entry is an assistant message containing only tool
  /// calls (no meaningful text). Used by the message list to group consecutive
  /// tool-only entries into a single bordered container.
  static bool isToolOnlyEntry(ConversationEntry entry) {
    if (entry.role != 'assistant') return false;
    for (final content in entry.content) {
      if (content is TextContent && content.text.trim().isNotEmpty) {
        return false;
      }
    }
    return entry.content.any((c) => c is ToolContent);
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    if (entry.role == 'user') {
      return _buildUserMessage(theme);
    } else {
      return _buildAssistantMessage(context, theme);
    }
  }

  Component _buildUserMessage(VideThemeData theme) {
    // Resolve attachments from entry content or locally tracked
    List<VideAttachment>? attachments;
    for (final c in entry.content) {
      if (c is AttachmentContent) {
        attachments = c.attachments;
        break;
      }
    }
    attachments ??= sentAttachments[entry.text];

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.base.primary.withOpacity(0.05),
            ),
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\u25b8 ', style: TextStyle(color: theme.base.primary)),
                Expanded(
                  child: Text(
                    entry.text,
                    style: TextStyle(color: theme.base.onSurface),
                  ),
                ),
              ],
            ),
          ),
          if (attachments != null && attachments.isNotEmpty)
            for (final attachment in attachments)
              Text(
                '  [${attachment.type}: ${attachment.filePath ?? attachment.mimeType ?? 'inline'}]',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Component _buildAssistantMessage(BuildContext context, VideThemeData theme) {
    final widgets = <Component>[];
    final pendingTools = <Component>[];

    void flushToolGroup() {
      if (pendingTools.isEmpty) return;
      widgets.addAll(pendingTools);
      pendingTools.clear();
    }

    for (final content in entry.content) {
      if (content is TextContent) {
        final hadTools = pendingTools.isNotEmpty;
        flushToolGroup();
        if (content.text.isNotEmpty) {
          if (hadTools) {
            widgets.add(SizedBox(height: 1));
          }
          final isContextFullError =
              content.text.toLowerCase().contains('prompt is too long') ||
              content.text.toLowerCase().contains('context window') ||
              content.text.toLowerCase().contains('token limit');

          widgets.add(MarkdownText(content.text, styleSheet: theme.markdownStyleSheet));

          if (isContextFullError) {
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
        final toolCall = ToolUseResponse(
          id: content.toolUseId,
          timestamp: DateTime.now(),
          toolName: content.toolName,
          parameters: content.toolInput,
          toolUseId: content.toolUseId,
        );
        final toolResult = content.result != null
            ? ToolResultResponse(
                id: content.toolUseId,
                timestamp: DateTime.now(),
                toolUseId: content.toolUseId,
                content: content.result!,
                isError: content.isError,
              )
            : null;

        final invocation = ConversationMessage.createTypedInvocation(
          toolCall,
          toolResult,
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

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widgets,

          // If no content yet but streaming, show loading
          if (entry.content.isEmpty && entry.isStreaming)
            EnhancedLoadingIndicator(agentId: agentId),
        ],
      ),
    );
  }
}
