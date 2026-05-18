import '../command.dart';

/// View and manage MCP servers for the current agent's session.
///
/// Usage:
///   /mcp                    - List all MCP servers with their status
///   /mcp reconnect <name>   - Reconnect a disconnected server
///   /mcp enable <name>      - Enable a server
///   /mcp disable <name>     - Disable a server
class McpCommand extends Command {
  @override
  String get name => 'mcp';

  @override
  String get description => 'View and manage MCP servers';

  @override
  String get usage => '/mcp [reconnect|enable|disable <name>]';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.getMcpServers == null) {
      return CommandResult.error('No active session');
    }

    final args = arguments?.trim() ?? '';

    if (args.isEmpty) {
      return _listServers(context);
    }

    final parts = args.split(RegExp(r'\s+'));
    final subcommand = parts[0].toLowerCase();
    final serverName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

    switch (subcommand) {
      case 'reconnect':
        return _reconnect(context, serverName);
      case 'enable':
        return _toggle(context, serverName, enabled: true);
      case 'disable':
        return _toggle(context, serverName, enabled: false);
      default:
        return CommandResult.error(
          'Unknown subcommand: $subcommand. '
          'Usage: /mcp [reconnect|enable|disable <name>]',
        );
    }
  }

  Future<CommandResult> _listServers(CommandContext context) async {
    final servers = await context.getMcpServers!();
    if (servers.isEmpty) {
      return CommandResult.success('No MCP servers configured');
    }

    final lines = <String>[];
    for (final server in servers) {
      var line = '${server.name}: ${server.status}';
      if (server.error != null) {
        line += ' (${server.error})';
      }
      lines.add(line);
    }

    return CommandResult.success(lines.join('\n'));
  }

  Future<CommandResult> _reconnect(
    CommandContext context,
    String? serverName,
  ) async {
    if (serverName == null || serverName.isEmpty) {
      return CommandResult.error('Usage: /mcp reconnect <server-name>');
    }
    if (context.reconnectMcpServer == null) {
      return CommandResult.error('Reconnect not available');
    }

    await context.reconnectMcpServer!(serverName);
    return CommandResult.success('Reconnecting $serverName...');
  }

  Future<CommandResult> _toggle(
    CommandContext context,
    String? serverName, {
    required bool enabled,
  }) async {
    if (serverName == null || serverName.isEmpty) {
      return CommandResult.error(
        'Usage: /mcp ${enabled ? 'enable' : 'disable'} <server-name>',
      );
    }
    if (context.toggleMcpServer == null) {
      return CommandResult.error('Toggle not available');
    }

    await context.toggleMcpServer!(serverName, enabled: enabled);
    final action = enabled ? 'Enabling' : 'Disabling';
    return CommandResult.success('$action $serverName...');
  }
}
