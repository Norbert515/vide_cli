import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';

import '../command.dart';

/// Exports the conversation as a Graphviz graph and opens it in Finder.
///
/// This command generates a DOT file representing the conversation flow,
/// renders it to SVG using Graphviz, and opens the result in Finder.
class GraphCommand extends Command {
  @override
  String get name => 'graph';

  @override
  String get description => 'Export conversation as a graph visualization';

  @override
  String get usage => '/graph';

  @override
  Future<CommandResult> execute(
      CommandContext context, String? arguments) async {
    if (context.getConversation == null) {
      return CommandResult.error('Cannot export: conversation not available');
    }

    final conversation = context.getConversation!() as Conversation;

    if (conversation.messages.isEmpty) {
      return CommandResult.error('No messages to export');
    }

    try {
      // Generate DOT content
      final dot = _generateDot(conversation);

      // Create temp directory for output
      final tempDir = Directory.systemTemp.createTempSync('vide_graph_');
      final dotFile = File('${tempDir.path}/conversation.dot');
      final svgFile = File('${tempDir.path}/conversation.svg');

      // Write DOT file
      await dotFile.writeAsString(dot);

      // Check if Graphviz is installed
      final whichResult = await Process.run('which', ['dot']);
      if (whichResult.exitCode != 0) {
        return CommandResult.error(
          'Graphviz not installed. Install with: brew install graphviz',
        );
      }

      // Render to SVG
      final result = await Process.run('dot', [
        '-Tsvg',
        dotFile.path,
        '-o',
        svgFile.path,
      ]);

      if (result.exitCode != 0) {
        return CommandResult.error(
          'Failed to render graph: ${result.stderr}',
        );
      }

      // Open in Finder
      await Process.run('open', ['-R', svgFile.path]);

      return CommandResult.success(
        'Graph exported to ${svgFile.path}',
      );
    } catch (e) {
      return CommandResult.error('Failed to export graph: $e');
    }
  }

  String _generateDot(Conversation conversation) {
    final buffer = StringBuffer();

    buffer.writeln('digraph conversation {');
    buffer.writeln('  rankdir=TB;');
    buffer.writeln('  node [fontname="Helvetica", fontsize=11];');
    buffer.writeln('  edge [fontname="Helvetica", fontsize=9];');
    buffer.writeln();

    // Style definitions
    buffer.writeln('  // Node styles');
    buffer.writeln(
        '  node [shape=box, style="rounded,filled", margin="0.2,0.1"];');
    buffer.writeln();

    var nodeIndex = 0;
    String? lastNodeId;
    final toolNodes = <String, String>{}; // toolUseId -> nodeId

    for (final message in conversation.messages) {
      // Skip system messages that are not meaningful
      if (message.messageType == MessageType.status ||
          message.messageType == MessageType.meta ||
          message.messageType == MessageType.completion ||
          message.messageType == MessageType.unknown) {
        continue;
      }

      final nodeId = 'n$nodeIndex';
      nodeIndex++;

      if (message.role == MessageRole.user) {
        // User message node
        final label = _escapeLabel(_truncate(message.content, 80));
        buffer.writeln(
            '  $nodeId [label="User:\\n$label", fillcolor="#E3F2FD", color="#1976D2"];');

        if (lastNodeId != null) {
          buffer.writeln('  $lastNodeId -> $nodeId;');
        }
        lastNodeId = nodeId;
      } else if (message.role == MessageRole.assistant) {
        // Process assistant responses
        final toolInvocations = message.toolInvocations;

        if (toolInvocations.isNotEmpty) {
          // Create nodes for each tool invocation
          for (final invocation in toolInvocations) {
            final toolNodeId = 'n$nodeIndex';
            nodeIndex++;

            final toolName = invocation.toolName;
            final params = _formatToolParams(invocation);
            final label = _escapeLabel('$toolName\\n$params');

            // Color based on tool type
            String fillColor;
            String borderColor;
            if (toolName == 'Read' || toolName == 'Glob' || toolName == 'Grep') {
              fillColor = '#E8F5E9';
              borderColor = '#388E3C';
            } else if (toolName == 'Write' || toolName == 'Edit') {
              fillColor = '#FFF3E0';
              borderColor = '#F57C00';
            } else if (toolName == 'Bash') {
              fillColor = '#F3E5F5';
              borderColor = '#7B1FA2';
            } else if (toolName == 'Task') {
              fillColor = '#E1F5FE';
              borderColor = '#0288D1';
            } else {
              fillColor = '#ECEFF1';
              borderColor = '#546E7A';
            }

            buffer.writeln(
                '  $toolNodeId [label="$label", fillcolor="$fillColor", color="$borderColor", shape=box];');

            if (lastNodeId != null) {
              buffer.writeln('  $lastNodeId -> $toolNodeId;');
            }

            // Store for result linking
            if (invocation.toolCall.toolUseId != null) {
              toolNodes[invocation.toolCall.toolUseId!] = toolNodeId;
            }

            // Add result node if available
            if (invocation.toolResult != null) {
              final resultNodeId = 'n$nodeIndex';
              nodeIndex++;

              final resultContent = invocation.toolResult!.content;
              final isError = invocation.toolResult!.isError;
              final resultLabel = _escapeLabel(_truncate(
                isError ? 'Error: $resultContent' : resultContent,
                60,
              ));

              final resultFill = isError ? '#FFEBEE' : '#F5F5F5';
              final resultBorder = isError ? '#C62828' : '#9E9E9E';

              buffer.writeln(
                  '  $resultNodeId [label="Result:\\n$resultLabel", fillcolor="$resultFill", color="$resultBorder", shape=note, fontsize=9];');
              buffer.writeln(
                  '  $toolNodeId -> $resultNodeId [style=dashed, color="#9E9E9E"];');

              lastNodeId = resultNodeId;
            } else {
              lastNodeId = toolNodeId;
            }
          }
        }

        // Add text response if present
        if (message.content.isNotEmpty) {
          final textNodeId = 'n$nodeIndex';
          nodeIndex++;

          final label =
              _escapeLabel('Assistant:\\n${_truncate(message.content, 100)}');
          buffer.writeln(
              '  $textNodeId [label="$label", fillcolor="#FFF8E1", color="#FFA000"];');

          if (lastNodeId != null) {
            buffer.writeln('  $lastNodeId -> $textNodeId;');
          }
          lastNodeId = textNodeId;
        }
      } else if (message.messageType == MessageType.compactBoundary) {
        // Compact boundary marker
        final compactNodeId = 'n$nodeIndex';
        nodeIndex++;

        buffer.writeln(
            '  $compactNodeId [label="--- Context Compacted ---", fillcolor="#FFCDD2", color="#D32F2F", shape=parallelogram];');

        if (lastNodeId != null) {
          buffer.writeln('  $lastNodeId -> $compactNodeId;');
        }
        lastNodeId = compactNodeId;
      }
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _formatToolParams(ToolInvocation invocation) {
    final params = invocation.parameters;
    final toolName = invocation.toolName;

    if (toolName == 'Read' || toolName == 'Write' || toolName == 'Edit') {
      final filePath = params['file_path'] as String?;
      if (filePath != null) {
        // Show just the filename
        final parts = filePath.split('/');
        return parts.last;
      }
    } else if (toolName == 'Bash') {
      final command = params['command'] as String?;
      if (command != null) {
        return _truncate(command, 40);
      }
    } else if (toolName == 'Glob') {
      final pattern = params['pattern'] as String?;
      return pattern ?? '';
    } else if (toolName == 'Grep') {
      final pattern = params['pattern'] as String?;
      return pattern ?? '';
    } else if (toolName == 'Task') {
      final description = params['description'] as String?;
      return description ?? '';
    }

    // Generic: show first string param
    for (final value in params.values) {
      if (value is String && value.isNotEmpty) {
        return _truncate(value, 40);
      }
    }

    return '';
  }

  String _truncate(String text, int maxLength) {
    // Remove newlines for cleaner display
    final clean = text.replaceAll('\n', ' ').replaceAll('\r', '').trim();
    if (clean.length <= maxLength) return clean;
    return '${clean.substring(0, maxLength - 3)}...';
  }

  String _escapeLabel(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }
}
