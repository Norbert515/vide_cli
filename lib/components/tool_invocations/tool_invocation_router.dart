import 'dart:convert';

import 'package:nocterm/nocterm.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/vide_core.dart';
import 'flutter_output_renderer.dart';
import 'terminal_output_renderer.dart';
import 'diff_renderer.dart';
import 'default_renderer.dart';

/// Main router for tool invocation rendering.
///
/// Routes tool invocations to appropriate renderers based on tool type:
/// - SubAgent tools (containing 'spawnAgent') → SubagentRenderer
/// - Flutter runtime start → FlutterOutputRenderer
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

    // Route 1: AskUserQuestion - show as a nice user response block
    if (invocation.toolName == 'mcp__vide-ask-user-question__askUserQuestion') {
      return _buildAskUserQuestionResult(context);
    }

    // Route 2: Flutter runtime start
    if (invocation.toolName == 'mcp__flutter-runtime__flutterStart') {
      return FlutterOutputRenderer(
        invocation: invocation,
        agentId: agentId,
        workingDirectory: workingDirectory,
        executionId: executionId,
      );
    }

    // Route 3: Terminal/Bash output
    if (invocation.toolName == 'Bash') {
      return TerminalOutputRenderer(
        invocation: invocation,
        agentId: agentId,
        workingDirectory: workingDirectory,
        executionId: executionId,
      );
    }

    // Route 4: Write/Edit/MultiEdit with successful result (show diff)
    if (_shouldShowDiff()) {
      return DiffRenderer(
        invocation: invocation,
        workingDirectory: workingDirectory,
        executionId: executionId,
        agentId: agentId,
      );
    }

    // Route 5: TodoWrite tool
    if (invocation.toolName == 'TodoWrite') {
      return SizedBox();
    }

    // Route 6: Default renderer for all other tools
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
    return invocation.toolName == 'mcp__vide-task-management__setTaskName' ||
        invocation.toolName == 'mcp__vide-task-management__setAgentTaskName' ||
        invocation.toolName == 'mcp__vide-agent__setAgentStatus' ||
        invocation.toolName == 'TodoWrite';
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
