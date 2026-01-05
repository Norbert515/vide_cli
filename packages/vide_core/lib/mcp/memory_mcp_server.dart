import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:sentry/sentry.dart';
import '../services/memory_service.dart';
import '../utils/working_dir_provider.dart';
import 'package:riverpod/riverpod.dart';

import '../models/agent_id.dart';

final memoryServerProvider = Provider.family<MemoryMCPServer, AgentId>((
  ref,
  agentId,
) {
  return MemoryMCPServer(
    memoryService: ref.watch(memoryServiceProvider),
    projectPath: ref.watch(workingDirProvider),
  );
});

/// MCP server for persistent memory storage.
///
/// This server wraps the MemoryService and scopes operations to a specific
/// working directory. Each MemoryServer instance is bound to one project path.
class MemoryMCPServer extends McpServerBase {
  static const String serverName = 'vide-memory';

  final MemoryService _memoryService;
  final String _projectPath;

  MemoryMCPServer({
    required MemoryService memoryService,
    required String projectPath,
  }) : _memoryService = memoryService,
       _projectPath = projectPath,
       super(name: serverName, version: '1.0.0');

  /// Report a memory operation error to Sentry with context
  Future<void> _reportError(
    Object e,
    StackTrace stackTrace,
    String toolName, {
    String? key,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setTag('mcp_server', serverName);
      scope.setTag('mcp_tool', toolName);
      if (key != null) {
        scope.setContexts('mcp_context', {'key': key});
      }
    });
    await Sentry.captureException(e, stackTrace: stackTrace);
  }

  @override
  List<String> get toolNames => [
    'memorySave',
    'memoryRetrieve',
    'memoryDelete',
    'memoryList',
  ];

  /// Gets the project path this server is scoped to.
  String get projectPath => _projectPath;

  /// Gets the underlying memory service.
  MemoryService get memoryService => _memoryService;

  @override
  void registerTools(McpServer server) {
    // Save memory
    server.tool(
      'memorySave',
      description:
          'Save a piece of information to memory with an associated key. This persists across the agent session.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'key': {
            'type': 'string',
            'description':
                'The key to associate with this memory (e.g., "build_instructions", "project_setup", "fvm_version")',
          },
          'value': {'type': 'string', 'description': 'The information to save'},
        },
        required: ['key', 'value'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final key = args['key'] as String;
        final value = args['value'] as String;

        try {
          await _memoryService.save(_projectPath, key, value);

          print(
            '[MemoryServer] Saved memory: "$key" (${value.length} chars) in project: $_projectPath',
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Memory saved successfully under key: "$key"'),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'memorySave', key: key);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error saving memory: $e')],
          );
        }
      },
    );

    // Retrieve memory
    server.tool(
      'memoryRetrieve',
      description: 'Retrieve a piece of information from memory by its key.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'key': {'type': 'string', 'description': 'The key to retrieve'},
        },
        required: ['key'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final key = args['key'] as String;

        try {
          final entry = await _memoryService.retrieve(_projectPath, key);
          if (entry == null) {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'No memory found for key: "$key"')],
            );
          }

          print(
            '[MemoryServer] Retrieved memory: "$key" (${entry.value.length} chars) from project: $_projectPath',
          );

          return CallToolResult.fromContent(
            content: [TextContent(text: entry.value)],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'memoryRetrieve', key: key);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error retrieving memory: $e')],
          );
        }
      },
    );

    // Delete memory
    server.tool(
      'memoryDelete',
      description: 'Delete a piece of information from memory by its key.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'key': {'type': 'string', 'description': 'The key to delete'},
        },
        required: ['key'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final key = args['key'] as String;

        try {
          final deleted = await _memoryService.delete(_projectPath, key);
          if (!deleted) {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'No memory found for key: "$key"')],
            );
          }

          print(
            '[MemoryServer] Deleted memory: "$key" from project: $_projectPath',
          );

          return CallToolResult.fromContent(
            content: [TextContent(text: 'Memory deleted successfully: "$key"')],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'memoryDelete', key: key);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error deleting memory: $e')],
          );
        }
      },
    );

    // List all memory keys
    server.tool(
      'memoryList',
      description:
          'List all available memory keys. Returns a list of all stored keys.',
      toolInputSchema: ToolInputSchema(properties: {}),
      callback: ({args, extra}) async {
        try {
          final keys = await _memoryService.listKeys(_projectPath);
          if (keys.isEmpty) {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'No memories stored yet.')],
            );
          }

          keys.sort();
          final keyList = keys.map((k) => '- $k').join('\n');

          print(
            '[MemoryServer] Listed ${keys.length} memory keys for project: $_projectPath',
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Stored memory keys (${keys.length}):\n$keyList',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'memoryList');
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error listing memory keys: $e')],
          );
        }
      },
    );
  }
}
