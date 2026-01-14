import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart' show McpServerBase, ServerState;
import 'package:riverpod/riverpod.dart';
import '../models/agent_id.dart';
import '../models/mcp_server_info.dart';

/// Provider for managing MCP state per agent.
final agentMcpStateProvider =
    StateNotifierProvider.family<AgentMcpStateNotifier, AgentMcpState, AgentId>(
      (ref, agentId) => AgentMcpStateNotifier(),
    );

/// Notifier for a single agent's MCP state.
class AgentMcpStateNotifier extends StateNotifier<AgentMcpState> {
  AgentMcpStateNotifier() : super(const AgentMcpState());

  final List<StreamSubscription<ServerState>> _subscriptions = [];

  /// Update state from Claude CLI init message
  void updateFromInitMessage(Map<String, dynamic> initJson) {
    final mcpServers = initJson['mcp_servers'] as List?;
    final tools = (initJson['tools'] as List?)?.cast<String>() ?? [];

    // Parse additional fields from init message
    final skills = (initJson['skills'] as List?)?.cast<String>() ?? [];
    final agents = (initJson['agents'] as List?)?.cast<String>() ?? [];
    final slashCommands =
        (initJson['slash_commands'] as List?)?.cast<String>() ?? [];
    final plugins = (initJson['plugins'] as List?)
            ?.map((p) => p as Map<String, dynamic>)
            .toList() ??
        [];
    final permissionMode = initJson['permissionMode'] as String?;
    final claudeCodeVersion = initJson['claude_code_version'] as String?;
    final model = initJson['model'] as String?;
    final cwd = initJson['cwd'] as String?;

    // Keep managed servers, replace external servers
    final managedServers = state.servers.where((s) => s.isManaged).toList();

    // Get managed server names to filter them out from external servers
    // (Claude reports all servers including vide-* ones, but we track those separately)
    final managedServerNames = managedServers.map((s) => s.name).toSet();

    // Parse external servers, excluding ones we're already managing
    final externalServers = mcpServers
            ?.map(
                (s) => McpServerInfo.fromInitMessage(s as Map<String, dynamic>))
            .where((s) => !managedServerNames.contains(s.name))
            .toList() ??
        [];

    state = AgentMcpState(
      servers: [...managedServers, ...externalServers],
      availableTools: tools,
      lastInitReceived: DateTime.now(),
      skills: skills,
      agents: agents,
      slashCommands: slashCommands,
      plugins: plugins,
      permissionMode: permissionMode,
      claudeCodeVersion: claudeCodeVersion,
      model: model,
      cwd: cwd,
    );
  }

  /// Add a managed server to track
  void addManagedServer(McpServerBase server, {int? port}) {
    final info = McpServerInfo(
      name: server.name,
      status: server.isRunning
          ? McpServerStatus.connected
          : McpServerStatus.stopped,
      scope: McpServerScope.builtin,
      isManaged: true,
      port: port,
      tools: server.toolNames,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      servers: [...state.servers.where((s) => s.name != server.name), info],
    );

    // Subscribe to state changes
    final sub = server.stateStream.listen((serverState) {
      _updateManagedServerState(server.name, serverState, server.toolNames);
    });
    _subscriptions.add(sub);
  }

  void _updateManagedServerState(
    String name,
    ServerState serverState,
    List<String> tools,
  ) {
    final status = switch (serverState) {
      ServerState.running => McpServerStatus.connected,
      ServerState.stopped => McpServerStatus.stopped,
      ServerState.error => McpServerStatus.error,
    };

    state = state.copyWith(
      servers: state.servers.map((s) {
        if (s.name == name) {
          return s.copyWith(
            status: status,
            tools: tools,
            lastUpdated: DateTime.now(),
          );
        }
        return s;
      }).toList(),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
