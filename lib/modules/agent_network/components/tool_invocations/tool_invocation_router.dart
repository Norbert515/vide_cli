import 'dart:convert';

import 'package:nocterm/nocterm.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/vide_core.dart' show AgentId;
import 'terminal_output_renderer.dart';
import 'diff_renderer.dart';
import 'default_renderer.dart';

/// Main router for tool invocation rendering.
///
/// Routes tool invocations to appropriate renderers based on tool type:
/// - SubAgent tools (containing 'spawnAgent') → SubagentRenderer
/// - Bash commands → TerminalOutputRenderer
/// - Write/Edit/MultiEdit (successful) → DiffRenderer
/// - All other tools → DefaultRenderer
class ToolInvocationRouter extends StatelessComponent {
  final ToolInvocation invocation;
  final String workingDirectory;
  final String executionId;
  final AgentId agentId;

  const ToolInvocationRouter({
    required this.invocation,
    required this.workingDirectory,
    required this.executionId,
    required this.agentId,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    // Route 0: Internal tools that should not be rendered
    // (they have their own UI or are invisible to the user)
    if (_isHiddenTool()) {
      return SizedBox();
    }

    // Route 1: ExitPlanMode - show plan accepted/rejected indicator
    if (invocation.toolName == 'ExitPlanMode') {
      return _buildExitPlanModeResult(context);
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

    // Route 5: Default renderer for all other tools
    return DefaultRenderer(
      invocation: invocation,
      workingDirectory: workingDirectory,
      executionId: executionId,
      agentId: agentId,
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

  /// Tools that should not be rendered at all (have their own UI or are internal)
  bool _isHiddenTool() {
    if (invocation.toolName == 'mcp__vide-task-management__setTaskName' ||
        invocation.toolName == 'mcp__vide-task-management__setAgentTaskName' ||
        invocation.toolName == 'mcp__vide-agent__setAgentStatus' ||
        invocation.toolName == 'TodoWrite' ||
        invocation.toolName == 'EnterPlanMode') {
      return true;
    }

    // Hide the Write tool when it writes to Claude's plans directory
    // (the plan content is shown in the PlanApprovalDialog instead)
    if (invocation.toolName == 'Write') {
      final filePath = invocation.parameters['file_path'] as String?;
      if (filePath != null && filePath.contains('.claude/plans/')) {
        return true;
      }
    }

    return false;
  }

  /// Build a display for ExitPlanMode tool results.
  ///
  /// Shows "Plan accepted" (green) or "Plan rejected: reason" (red) based on
  /// whether the tool succeeded or was denied.
  Component _buildExitPlanModeResult(BuildContext context) {
    // While waiting for user response, show nothing (dialog handles it)
    if (!invocation.hasResult) {
      return SizedBox();
    }

    if (invocation.isError) {
      // Plan was rejected - show rejection with feedback if available
      final reason = invocation.resultContent ?? 'User rejected the plan';
      return Container(
        padding: EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('◇ ', style: TextStyle(color: Colors.red)),
            Expanded(
              child: Text(
                'Plan rejected: $reason',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    // Plan was accepted
    return Container(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text('◆ ', style: TextStyle(color: Colors.green)),
          Text(
            'Plan accepted',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

      final answers = Map<String, dynamic>.from(decoded);
      if (answers.isEmpty) {
        // User cancelled
        return Row(
          children: [
            Text('◇ ', style: TextStyle(color: Colors.grey)),
            Text(
              'Question cancelled',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
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
                  Text('◆ ', style: TextStyle(color: Colors.cyan)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.key, style: TextStyle(color: Colors.grey)),
                        Text(
                          '  ${entry.value}',
                          style: TextStyle(
                            color: Colors.white,
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
