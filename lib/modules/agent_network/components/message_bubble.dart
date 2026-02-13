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
          Text(
            '> ${entry.text}',
            style: TextStyle(color: theme.base.onSurface),
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

    for (final content in entry.content) {
      if (content is TextContent) {
        if (content.text.isNotEmpty) {
          // Check for context-full errors and add helpful hint
          final isContextFullError =
              content.text.toLowerCase().contains('prompt is too long') ||
              content.text.toLowerCase().contains('context window') ||
              content.text.toLowerCase().contains('token limit');

          widgets.add(MarkdownText(content.text));

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
        // Bridge to claude_sdk ToolInvocation for rendering
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

        // Use factory method to create typed invocation
        final invocation = ConversationMessage.createTypedInvocation(
          toolCall,
          toolResult,
        );

        widgets.add(
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
