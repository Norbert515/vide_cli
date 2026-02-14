import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:sentry/sentry.dart';
import '../../logging/vide_logger.dart';
import '../../models/agent_id.dart';
import '../../models/agent_status.dart';
import '../../agent_network/agent_network_manager.dart';
import '../../team_framework/trigger_service.dart';
import '../../agent_network/agent_status_manager.dart';
import 'package:riverpod/riverpod.dart';

final ProviderFamily<AgentMCPServer, AgentId> agentServerProvider =
    Provider.family<AgentMCPServer, AgentId>((
  ref,
  agentId,
) {
  return AgentMCPServer(
    callerAgentId: agentId,
    networkManager: ref.watch(agentNetworkManagerProvider.notifier),
    getStatusNotifier: (id) => ref.read(agentStatusProvider(id).notifier),
    getStatus: (id) => ref.read(agentStatusProvider(id)),
    getTriggerService: () => ref.read(triggerServiceProvider),
  );
});

/// MCP server for agent network operations.
///
/// This server enables agents to:
/// - Spawn new agents into the agent network
/// - Send messages to other agents asynchronously
///
/// This is a thin wrapper around [AgentNetworkManager] methods.
class AgentMCPServer extends McpServerBase {
  static const String serverName = 'vide-agent';

  final AgentId callerAgentId;
  final AgentNetworkManager _networkManager;
  final AgentStatusNotifier Function(AgentId) _getStatusNotifier;
  final AgentStatus Function(AgentId) _getStatus;
  final TriggerService Function() _getTriggerService;

  AgentMCPServer({
    required this.callerAgentId,
    required AgentNetworkManager networkManager,
    required AgentStatusNotifier Function(AgentId) getStatusNotifier,
    required AgentStatus Function(AgentId) getStatus,
    required TriggerService Function() getTriggerService,
  }) : _networkManager = networkManager,
       _getStatusNotifier = getStatusNotifier,
       _getStatus = getStatus,
       _getTriggerService = getTriggerService,
       super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => [
    'spawnAgent',
    'sendMessageToAgent',
    'setAgentStatus',
    'terminateAgent',
  ];

  @override
  void registerTools(McpServer server) {
    _registerSpawnAgentTool(server);
    _registerSendMessageToAgentTool(server);
    _registerSetAgentStatusTool(server);
    _registerTerminateAgentTool(server);
  }

  void _registerSpawnAgentTool(McpServer server) {
    server.tool(
      'spawnAgent',
      description: '''Spawn a new agent into the agent network.

The new agent will be added to the current network and can receive messages.
Use this to delegate tasks to specialized agents.

The available agent types depend on the current team's agent list. Use the agent
personality name (e.g., 'solid-implementer', 'creative-explorer', 'deep-researcher').

Returns the ID of the newly spawned agent which can be used with sendMessageToAgent.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'agentType': {
            'type': 'string',
            'description':
                'The agent type/personality to spawn from the current team '
                '(e.g., "solid-implementer", "creative-explorer", "deep-researcher"). '
                'Cannot spawn "lead" - that is the main agent.',
          },
          'name': {
            'type': 'string',
            'description':
                'A short, descriptive name for the agent (e.g., "Auth Research", "DB Fix", "UI Tests"). This will be displayed in the UI.',
          },
          'initialPrompt': {
            'type': 'string',
            'description':
                'The initial message/task to send to the new agent. Be specific and provide all necessary context.',
          },
          'workingDirectory': {
            'type': 'string',
            'description':
                'Optional working directory for this agent. If not provided, '
                'uses the session working directory. Use this to spawn an agent '
                'in a different directory (e.g., a git worktree).',
          },
        },
        required: ['agentType', 'name', 'initialPrompt'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final agentType = args['agentType'] as String;
        final name = args['name'] as String;
        final initialPrompt = args['initialPrompt'] as String;
        final workingDirectory = args['workingDirectory'] as String?;

        try {
          final newAgentId = await _networkManager.spawnAgent(
            agentType: agentType,
            name: name,
            initialPrompt: initialPrompt,
            spawnedBy: callerAgentId,
            workingDirectory: workingDirectory,
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Successfully spawned "$agentType" agent "$name".\n'
                    'Agent ID: $newAgentId\n'
                    'Spawned by: $callerAgentId\n\n'
                    'The agent has been sent your initial message and is now working on it. '
                    'Use sendMessageToAgent to communicate with this agent.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'spawnAgent');
            scope.setContexts('mcp_context', {
              'agent_type': agentType,
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error spawning agent: $e')],
          );
        }
      },
    );
  }

  void _registerSendMessageToAgentTool(McpServer server) {
    server.tool(
      'sendMessageToAgent',
      description: '''Send a message to another agent asynchronously.

This is fire-and-forget - the message is sent and you continue immediately.
The target agent will process your message and can respond back by sending
a message to you, which will "wake you up" with their response.

Use this to coordinate with other agents in the network.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'targetAgentId': {
            'type': 'string',
            'description': 'The ID of the agent to send the message to',
          },
          'message': {
            'type': 'string',
            'description': 'The message to send to the agent',
          },
        },
        required: ['targetAgentId', 'message'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final targetAgentId = args['targetAgentId'] as String;
        final message = args['message'] as String;

        try {
          _networkManager.sendMessageToAgent(
            targetAgentId: targetAgentId,
            message: message,
            sentBy: callerAgentId,
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Message sent to agent $targetAgentId.\n'
                    'The agent will process your message and can respond back to you.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'sendMessageToAgent');
            scope.setContexts('mcp_context', {
              'target_agent_id': targetAgentId,
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error sending message: $e')],
          );
        }
      },
    );
  }

  void _registerSetAgentStatusTool(McpServer server) {
    server.tool(
      'setAgentStatus',
      description:
          '''Set the current status of this agent. Use this to communicate your state to the user.

Call this when:
- You are waiting for another agent to respond: "waitingForAgent"
- You are waiting for user input/approval: "waitingForUser"
- You have finished your work: "idle"
- You are actively working (default, usually set automatically): "working"''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'status': {
            'type': 'string',
            'enum': ['working', 'waitingForAgent', 'waitingForUser', 'idle'],
            'description': 'The current status of the agent',
          },
        },
        required: ['status'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final statusStr = args['status'] as String;
        final status = AgentStatusExtension.fromString(statusStr);

        if (status == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Error: Invalid status "$statusStr". Must be one of: working, waitingForAgent, waitingForUser, idle',
              ),
            ],
          );
        }

        final networkId =
            _networkManager.currentState.currentNetwork?.id;
        VideLogger.instance.info(
          'AgentMCPServer',
          'setAgentStatus called: agent=$callerAgentId requested=$statusStr',
          sessionId: networkId,
        );

        try {
          _getStatusNotifier(callerAgentId).setStatus(status);

          // If agent became idle, check if all agents are now idle
          if (status == AgentStatus.idle) {
            _checkAllAgentsIdle();
          }

          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Agent status updated to: "$statusStr"'),
            ],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'setAgentStatus');
            scope.setContexts('mcp_context', {
              'status': statusStr,
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error updating agent status: $e')],
          );
        }
      },
    );
  }

  /// Check if all agents in the network are idle, and fire trigger if so.
  void _checkAllAgentsIdle() {
    final network = _networkManager.currentState.currentNetwork;
    if (network == null) return;

    // Check status of all agents
    var allIdle = true;
    for (final agent in network.agents) {
      final status = _getStatus(agent.id);
      if (status != AgentStatus.idle) {
        allIdle = false;
        break;
      }
    }

    VideLogger.instance.debug(
      'AgentMCPServer',
      '_checkAllAgentsIdle: allIdle=$allIdle agentCount=${network.agents.length}',
      sessionId: network.id,
    );

    if (allIdle && network.agents.isNotEmpty) {
      VideLogger.instance.info(
        'AgentMCPServer',
        'All ${network.agents.length} agents are idle, firing onAllAgentsIdle trigger',
        sessionId: network.id,
      );
      // Fire trigger in background (don't block the tool response)
      () async {
        try {
          final triggerService = _getTriggerService();
          final context = TriggerContext(
            triggerPoint: TriggerPoint.onAllAgentsIdle,
            network: network,
            teamName: network.team,
          );
          await triggerService.fire(context);
        } catch (e) {
          VideLogger.instance.error(
            'AgentMCPServer',
            'Error firing onAllAgentsIdle trigger: $e',
            sessionId: network.id,
          );
        }
      }();
    }
  }

  void _registerTerminateAgentTool(McpServer server) {
    server.tool(
      'terminateAgent',
      description: '''Terminate an agent and remove it from the network.

Use this when:
- An agent has completed its work and is no longer needed
- You want to clean up agents that have reported back
- An agent needs to self-terminate after finishing

The agent will be stopped, removed from the network, and will no longer appear in the UI.
Any agent can terminate any other agent, including itself.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'targetAgentId': {
            'type': 'string',
            'description': 'The ID of the agent to terminate',
          },
          'reason': {
            'type': 'string',
            'description': 'Optional reason for termination (for logging)',
          },
        },
        required: ['targetAgentId'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final targetAgentId = args['targetAgentId'] as String;
        final reason = args['reason'] as String?;

        try {
          await _networkManager.terminateAgent(
            targetAgentId: targetAgentId,
            terminatedBy: callerAgentId,
            reason: reason,
          );

          final selfTerminated = targetAgentId == callerAgentId;
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: selfTerminated
                    ? 'Successfully self-terminated. This agent has been removed from the network.'
                    : 'Successfully terminated agent $targetAgentId. The agent has been removed from the network.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'terminateAgent');
            scope.setContexts('mcp_context', {
              'target_agent_id': targetAgentId,
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error terminating agent: $e')],
          );
        }
      },
    );
  }
}
