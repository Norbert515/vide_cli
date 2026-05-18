import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:sentry/sentry.dart';
import 'package:riverpod/riverpod.dart';
import '../../models/agent_id.dart';
import '../../agent_network/agent_network_manager.dart';
import '../../team_framework/trigger_service.dart';

final taskManagementServerProvider =
    Provider.family<TaskManagementServer, AgentId>((ref, agentId) {
      return TaskManagementServer(
        callerAgentId: agentId,
        networkManager: ref.watch(agentNetworkManagerProvider.notifier),
        getTriggerService: () => ref.read(triggerServiceProvider),
      );
    });

/// MCP server for task management operations
class TaskManagementServer extends McpServerBase {
  static const String serverName = 'vide-task-management';

  final AgentId callerAgentId;
  final AgentNetworkManager _networkManager;
  final TriggerService Function() _getTriggerService;

  TaskManagementServer({
    required this.callerAgentId,
    required AgentNetworkManager networkManager,
    required TriggerService Function() getTriggerService,
  }) : _networkManager = networkManager,
       _getTriggerService = getTriggerService,
       super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => [
    'setTaskName',
    'setAgentTaskName',
    'markTaskComplete',
  ];

  @override
  void registerTools(McpServer server) {
    _registerSetTaskNameTool(server);
    _registerSetAgentTaskNameTool(server);
    _registerMarkTaskCompleteTool(server);
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
          await _networkManager.updateGoal(taskName);

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
          await _networkManager.updateAgentTaskName(callerAgentId, taskName);

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

  void _registerMarkTaskCompleteTool(McpServer server) {
    server.tool(
      'markTaskComplete',
      description:
          'Mark the current task as complete. This fires the onTaskComplete trigger which may spawn agents like code-reviewer depending on team configuration. Call this when the main task goal has been achieved.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'summary': {
            'type': 'string',
            'description':
                'Brief summary of what was accomplished (e.g., "Implemented JWT authentication with refresh tokens")',
          },
          'filesChanged': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Optional list of files that were changed (e.g., ["lib/auth.dart", "test/auth_test.dart"])',
          },
        },
        required: ['summary'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final summary = args['summary'] as String;
        final filesChanged = (args['filesChanged'] as List?)?.cast<String>();

        try {
          final network = _networkManager.currentState.currentNetwork;

          if (network == null) {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: No active network')],
            );
          }

          // Fire the onTaskComplete trigger
          final triggerService = _getTriggerService();
          final context = TriggerContext(
            triggerPoint: TriggerPoint.onTaskComplete,
            network: network,
            teamName: network.team,
            taskName: summary,
            filesChanged: filesChanged,
          );

          final spawnedAgentId = await triggerService.fire(context);

          if (spawnedAgentId != null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Task marked complete: "$summary"\n'
                      'Triggered agent spawned for review.',
                ),
              ],
            );
          } else {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Task marked complete: "$summary"\n'
                      'No trigger configured for onTaskComplete in this team.',
                ),
              ],
            );
          }
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'markTaskComplete');
            scope.setContexts('mcp_context', {
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error marking task complete: $e')],
          );
        }
      },
    );
  }
}
