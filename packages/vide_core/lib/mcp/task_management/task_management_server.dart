import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:sentry/sentry.dart';
import 'package:riverpod/riverpod.dart';
import '../../../models/agent_id.dart';
import '../../../services/agent_network_manager.dart';

final taskManagementServerProvider =
    Provider.family<TaskManagementServer, AgentId>((ref, agentId) {
      return TaskManagementServer(callerAgentId: agentId, ref: ref);
    });

/// MCP server for task management operations
class TaskManagementServer extends McpServerBase {
  static const String serverName = 'vide-task-management';

  final AgentId callerAgentId;
  final Ref _ref;

  TaskManagementServer({required this.callerAgentId, required Ref ref})
    : _ref = ref,
      super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => ['setTaskName', 'setAgentTaskName'];

  @override
  void registerTools(McpServer server) {
    _registerSetTaskNameTool(server);
    _registerSetAgentTaskNameTool(server);
  }

  void _registerSetTaskNameTool(McpServer server) {
    server.tool(
      'setTaskName',
      description:
          'Set or update the name/description of the current task. Call this as soon as you understand what the task is about to give it a clear, descriptive name. You can call this multiple times if your understanding of the task evolves.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'taskName': {
            'type': 'string',
            'description':
                'Clear, concise name describing what the task is about (e.g., "Add dark mode toggle", "Fix authentication bug", "Implement user profile page")',
          },
        },
        required: ['taskName'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final taskName = args['taskName'] as String;

        try {
          await _ref
              .read(agentNetworkManagerProvider.notifier)
              .updateGoal(taskName);

          return CallToolResult.fromContent(
            content: [TextContent(text: 'Task name updated to: "$taskName"')],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'setTaskName');
            scope.setContexts('mcp_context', {
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error updating task name: $e')],
          );
        }
      },
    );
  }

  void _registerSetAgentTaskNameTool(McpServer server) {
    server.tool(
      'setAgentTaskName',
      description:
          'Set or update the current task name for this agent. Use this to indicate what specific task this agent is currently working on. This is separate from the overall task name (setTaskName) which describes the entire network\'s goal.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'taskName': {
            'type': 'string',
            'description':
                'Clear, concise name describing what this agent is currently working on (e.g., "Researching auth patterns", "Implementing login form", "Running unit tests")',
          },
        },
        required: ['taskName'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final taskName = args['taskName'] as String;

        try {
          await _ref
              .read(agentNetworkManagerProvider.notifier)
              .updateAgentTaskName(callerAgentId, taskName);

          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Agent task name updated to: "$taskName"'),
            ],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'setAgentTaskName');
            scope.setContexts('mcp_context', {
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error updating agent task name: $e')],
          );
        }
      },
    );
  }
}
