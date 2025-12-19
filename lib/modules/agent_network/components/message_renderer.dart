import 'package:nocterm/nocterm.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/components/tool_invocations/tool_invocation_router.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/state/agent_response_times.dart';

/// Renders a single conversation message (user or assistant).
class MessageRenderer extends StatelessComponent {
  /// The message to render
  final ConversationMessage message;

  /// Dynamic loading words for enhanced loading indicator
  final List<String>? dynamicLoadingWords;

  /// Agent session ID for response time lookups
  final String agentSessionId;

  /// Working directory for tool invocations
  final String workingDirectory;

  /// Network/execution ID for tool invocations
  final String executionId;

  /// Current output token count (for loading indicator)
  final int? outputTokens;

  const MessageRenderer({
    super.key,
    required this.message,
    required this.agentSessionId,
    required this.workingDirectory,
    required this.executionId,
    this.dynamicLoadingWords,
    this.outputTokens,
  });

  @override
  Component build(BuildContext context) {
    if (message.role == MessageRole.user) {
      return Container(
        padding: EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('> ${message.content}', style: TextStyle(color: Colors.white)),
            if (message.attachments != null && message.attachments!.isNotEmpty)
              for (var attachment in message.attachments!)
                Text(
                  '  📎 ${attachment.path ?? "image"}',
                  style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                ),
          ],
        ),
      );
    } else {
      // Build tool invocations by pairing calls with their results
      final toolCallsById = <String, ToolUseResponse>{};
      final toolResultsById = <String, ToolResultResponse>{};

      // First pass: collect all tool calls and results by ID
      for (final response in message.responses) {
        if (response is ToolUseResponse && response.toolUseId != null) {
          toolCallsById[response.toolUseId!] = response;
        } else if (response is ToolResultResponse) {
          toolResultsById[response.toolUseId] = response;
        }
      }

      // Second pass: render responses in order, combining tool calls with their results
      final widgets = <Component>[];
      final renderedToolResults = <String>{};

      for (final response in message.responses) {
        if (response is TextResponse) {
          if (response.content.isEmpty && message.isStreaming) {
            widgets.add(EnhancedLoadingIndicator(
              responseStartTime: AgentResponseTimes.get(agentSessionId),
              outputTokens: outputTokens,
              dynamicWords: dynamicLoadingWords,
            ));
          } else {
            widgets.add(MarkdownText(response.content));
          }
        } else if (response is ToolUseResponse) {
          // Check if we have a result for this tool call
          final result = response.toolUseId != null ? toolResultsById[response.toolUseId] : null;

          String? subagentSessionId;

          // Use factory method to create typed invocation
          final invocation = ConversationMessage.createTypedInvocation(response, result, sessionId: subagentSessionId);

          widgets.add(
            ToolInvocationRouter(
              key: ValueKey(response.toolUseId ?? response.id),
              invocation: invocation,
              workingDirectory: workingDirectory,
              executionId: executionId,
              agentId: agentSessionId,
            ),
          );
          if (result != null && response.toolUseId != null) {
            renderedToolResults.add(response.toolUseId!);
          }
        } else if (response is ToolResultResponse) {
          // Only show tool result if it wasn't already paired with its call
          if (!renderedToolResults.contains(response.toolUseId)) {
            // This is an orphaned tool result (shouldn't normally happen)
            widgets.add(
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text('[orphaned result: ${response.content}]', style: TextStyle(color: Colors.red)),
              ),
            );
          }
        }
      }

      return Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widgets,

            // If no responses yet but streaming, show loading
            if (message.responses.isEmpty && message.isStreaming)
              EnhancedLoadingIndicator(
                responseStartTime: AgentResponseTimes.get(agentSessionId),
                outputTokens: outputTokens,
                dynamicWords: dynamicLoadingWords,
              ),

            if (message.error != null)
              Container(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Text(
                  '[error: ${message.error}]',
                  style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                ),
              ),
          ],
        ),
      );
    }
  }
}
