import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:path/path.dart' as path;
import 'package:sentry/sentry.dart';
import '../../../models/agent_id.dart';
import '../../../models/agent_status.dart';
import '../../../services/agent_network_manager.dart';
import '../../../state/agent_status_manager.dart';
import 'package:riverpod/riverpod.dart';

final agentServerProvider = Provider.family<AgentMCPServer, AgentId>((
  ref,
  agentId,
) {
  return AgentMCPServer(
    callerAgentId: agentId,
    networkManager: ref.watch(agentNetworkManagerProvider.notifier),
    ref: ref,
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
  final Ref _ref;

  AgentMCPServer({
    required this.callerAgentId,
    required AgentNetworkManager networkManager,
    required Ref ref,
  }) : _networkManager = networkManager,
       _ref = ref,
       super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => [
    'spawnAgent',
    'sendMessageToAgent',
    'setAgentStatus',
    'terminateAgent',
    'setSessionWorktree',
  ];

  @override
  void registerTools(McpServer server) {
    _registerSpawnAgentTool(server);
    _registerSendMessageToAgentTool(server);
    _registerSetAgentStatusTool(server);
    _registerTerminateAgentTool(server);
    _registerSetSessionWorktreeTool(server);
  }

  void _registerSpawnAgentTool(McpServer server) {
    server.tool(
      'spawnAgent',
      description: '''Spawn a new agent into the agent network.

The new agent will be added to the current network and can receive messages.
Use this to delegate tasks to specialized agents.

Available agent types:
- implementation: Implements features and fixes based on clear requirements. Has access to Git, Memory, TaskManagement, FlutterRuntime, Dart, and Figma.
- contextCollection: Gathers context and explores the codebase. Good for research and understanding.
- flutterTester: Tests Flutter applications, takes screenshots, validates app behavior.
- planning: Creates detailed implementation plans for complex tasks.

Returns the ID of the newly spawned agent which can be used with sendMessageToAgent.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'agentType': {
            'type': 'string',
            'enum': [
              'implementation',
              'contextCollection',
              'flutterTester',
              'planning',
            ],
            'description': 'The type of agent to spawn',
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
        },
        required: ['agentType', 'name', 'initialPrompt'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final agentTypeStr = args['agentType'] as String;
        final name = args['name'] as String;
        final initialPrompt = args['initialPrompt'] as String;

        // Parse agent type
        final SpawnableAgentType? agentType = _parseAgentType(agentTypeStr);
        if (agentType == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Unknown agent type: $agentTypeStr'),
            ],
          );
        }

        try {
          final newAgentId = await _networkManager.spawnAgent(
            agentType: agentType,
            name: name,
            initialPrompt: initialPrompt,
            spawnedBy: callerAgentId,
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Successfully spawned $agentTypeStr agent "$name".\n'
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
              'agent_type': agentTypeStr,
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

  SpawnableAgentType? _parseAgentType(String agentTypeStr) {
    return switch (agentTypeStr) {
      'implementation' => SpawnableAgentType.implementation,
      'contextCollection' => SpawnableAgentType.contextCollection,
      'flutterTester' => SpawnableAgentType.flutterTester,
      'planning' => SpawnableAgentType.planning,
      _ => null,
    };
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

        try {
          _ref
              .read(agentStatusProvider(callerAgentId).notifier)
              .setStatus(status);

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

  void _registerSetSessionWorktreeTool(McpServer server) {
    server.tool(
      'setSessionWorktree',
      description:
          '''Set the worktree path for this session. All new agents will use this directory.

Use this after creating a git worktree to make all agents work in that directory:
1. Create worktree: gitWorktreeAdd(path: "../project-feature", branch: "feature/name", createBranch: true)
2. Set session directory: setSessionWorktree(path: "/absolute/path/to/project-feature")

This is useful for:
- Working on features in isolation
- Keeping the main branch clean
- Allowing easy context switching

Pass null or empty string to clear the worktree and return to the original directory.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {
            'type': 'string',
            'description':
                'Absolute path to the worktree directory. Pass empty string to clear.',
          },
        },
        required: ['path'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final pathArg = args['path'] as String;

        try {
          // Handle clearing the worktree
          if (pathArg.isEmpty) {
            await _networkManager.setWorktreePath(null);
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Session worktree cleared. Agents will now use the original working directory: ${_networkManager.workingDirectory}',
                ),
              ],
            );
          }

          // Convert to absolute path
          final absolutePath = path.isAbsolute(pathArg)
              ? pathArg
              : Directory(pathArg).absolute.path;

          // Validate directory exists
          final directory = Directory(absolutePath);
          if (!await directory.exists()) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text: 'Error: Directory does not exist: $absolutePath',
                ),
              ],
            );
          }

          await _networkManager.setWorktreePath(absolutePath);

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Session worktree set to: $absolutePath\n\n'
                    'All newly spawned agents will now work in this directory. '
                    'Existing agents will continue using their original directory.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'setSessionWorktree');
            scope.setContexts('mcp_context', {
              'path': pathArg,
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error setting session worktree: $e')],
          );
        }
      },
    );
  }
}
