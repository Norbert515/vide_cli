import 'dart:convert';

import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show AgentId, ToolContent;
import 'package:vide_cli/theme/theme.dart';
import 'plan_accepted_renderer.dart';
import 'terminal_output_renderer.dart';
import 'diff_renderer.dart';
import 'shared/tool_header.dart';

/// Main router for tool invocation rendering.
///
/// Routes tool invocations to appropriate renderers based on tool type:
/// - SubAgent tools (containing 'spawnAgent') → SubagentRenderer
/// - Bash commands → TerminalOutputRenderer
/// - Write/Edit/MultiEdit (successful) → DiffRenderer
/// - All other tools → ToolHeader
class ToolInvocationRouter extends StatelessComponent {
  final AgentToolInvocation invocation;
  final String workingDirectory;
  final String executionId;
  final AgentId agentId;
  final String? planContent;

  const ToolInvocationRouter({
    required this.invocation,
    required this.workingDirectory,
    required this.executionId,
    required this.agentId,
    this.planContent,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    // Route 0: Internal tools that should not be rendered
    // (they have their own UI or are invisible to the user)
    if (isHiddenTool(invocation.toolName, invocation.parameters)) {
      return SizedBox();
    }

    // Route 1: ExitPlanMode - show plan accepted/rejected with preview
    if (invocation.toolName == 'ExitPlanMode') {
      return PlanAcceptedRenderer(
        invocation: invocation,
        planContent: planContent,
      );
    }

    // Route 2: AskUserQuestion - show as a nice user response block
    if (invocation.toolName == 'mcp__vide-ask-user-question__askUserQuestion') {
      return _buildAskUserQuestionResult(context);
    }

    // Route 2: Terminal/Bash output
    if (invocation.toolName == 'Bash') {
      return TerminalOutputRenderer(
        invocation: invocation,
        agentId: agentId,
        workingDirectory: workingDirectory,
        executionId: executionId,
      );
    }

    // Route 3: Write/Edit/MultiEdit with successful result (show diff)
    if (_shouldShowDiff()) {
      return DiffRenderer(
        invocation: invocation,
        workingDirectory: workingDirectory,
        executionId: executionId,
        agentId: agentId,
      );
    }

    // Route 4: TodoWrite tool
    if (invocation.toolName == 'TodoWrite') {
      return SizedBox();
    }

    // Route 5: Default — just show the tool header
    return ToolHeader(
      invocation: invocation,
      workingDirectory: workingDirectory,
    );
  }

  /// Determines if diff view should be shown for Write/Edit/MultiEdit tools
  bool _shouldShowDiff() {
    final toolName = invocation.toolName.toLowerCase();
    return (toolName == 'write' ||
            toolName == 'edit' ||
            toolName == 'multiedit') &&
        invocation.hasResult &&
        !invocation.isError;
  }

  /// Whether a tool with [toolName] and [toolInput] should not be rendered.
  ///
  /// Delegates to [ToolContent.isHidden] which is the single source of truth.
  static bool isHiddenTool(String toolName, Map<String, dynamic> toolInput) {
    return ToolContent(
      toolUseId: '',
      toolName: toolName,
      toolInput: toolInput,
    ).isHidden;
  }

  /// Build a nice display for AskUserQuestion tool results
  Component _buildAskUserQuestionResult(BuildContext context) {
    // If no result yet, show nothing (the dialog is handling the interaction)
    if (!invocation.hasResult) {
      return SizedBox();
    }

    // Parse the result to show what the user answered
    final resultContent = invocation.resultContent;
    if (resultContent == null || resultContent.isEmpty) {
      return SizedBox();
    }

    // Try to parse the JSON response
    try {
      final decoded = jsonDecode(resultContent);
      // The result is a map of question -> answer
      if (decoded is! Map) {
        return SizedBox();
      }

      final theme = VideTheme.of(context);

      final answers = Map<String, dynamic>.from(decoded);
      if (answers.isEmpty) {
        // User cancelled
        return Row(
          children: [
            Text('◇ ', style: TextStyle(color: theme.base.outline)),
            Text(
              'Question cancelled',
              style: TextStyle(
                color: theme.base.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      }

      // Show user's answers nicely with padding
      return Container(
        padding: EdgeInsets.symmetric(vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in answers.entries) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('◆ ', style: TextStyle(color: theme.base.primary)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(color: theme.base.outline),
                        ),
                        Text(
                          '  ${entry.value}',
                          style: TextStyle(
                            color: theme.base.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      // If parsing fails, show nothing
      return SizedBox();
    }
  }
}
