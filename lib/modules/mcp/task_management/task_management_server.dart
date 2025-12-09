import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_api/claude_api.dart';
import 'package:riverpod/riverpod.dart';
import '../../agent_network/models/agent_id.dart';
import '../../agent_network/service/agent_network_manager.dart';

final taskManagementServerProvider = Provider.family<TaskManagementServer, AgentId>((ref, agentId) {
  return TaskManagementServer(
    callerAgentId: agentId,
    ref: ref,
  );
});

/// MCP server for task management operations
class TaskManagementServer extends McpServerBase {
  static const String serverName = 'parott-task-management';

  final AgentId callerAgentId;
  final Ref _ref;

  TaskManagementServer({
    required this.callerAgentId,
    required Ref ref,
  })  : _ref = ref,
        super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => ['setTaskName'];

  @override
  void registerTools(McpServer server) {
    _registerSetTaskNameTool(server);
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
          return CallToolResult.fromContent(content: [TextContent(text: 'Error: No arguments provided')]);
        }

        final taskName = args['taskName'] as String;

        try {
          await _ref.read(agentNetworkManagerProvider.notifier).updateGoal(taskName);

          return CallToolResult.fromContent(content: [TextContent(text: 'Task name updated to: "$taskName"')]);
        } catch (e) {
          return CallToolResult.fromContent(content: [TextContent(text: 'Error updating task name: $e')]);
        }
      },
    );
  }
}
