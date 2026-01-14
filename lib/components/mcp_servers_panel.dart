import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Panel displaying MCP servers and their status for an agent.
class McpServersPanel extends StatefulComponent {
  final AgentId agentId;
  final bool focused;
  final bool expanded;
  final double width;
  final VoidCallback? onExitLeft;

  const McpServersPanel({
    required this.agentId,
    this.focused = false,
    this.expanded = true,
    this.width = 32,
    this.onExitLeft,
    super.key,
  });

  @override
  State<McpServersPanel> createState() => _McpServersPanelState();
}

class _McpServersPanelState extends State<McpServersPanel> {
  int _selectedIndex = 0;
  bool _showTools = false;
  final _scrollController = ScrollController();

  void _handleKeyEvent(
    KeyboardEvent event,
    List<McpServerInfo> servers,
  ) {
    if (!component.focused) return;

    final serverCount = servers.length;
    if (serverCount == 0) return;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < serverCount - 1) {
        setState(() => _selectedIndex++);
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExitLeft?.call();
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      setState(() => _showTools = !_showTools);
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final mcpState = context.watch(agentMcpStateProvider(component.agentId));
    final servers = mcpState.servers;

    if (!component.expanded) {
      // Collapsed view - just show count
      return SizedBox(
        width: 3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              '{}',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            Text(
              '${mcpState.connectedServers.length}',
              style: TextStyle(
                color: mcpState.errorServers.isNotEmpty
                    ? theme.status.error
                    : theme.status.idle,
              ),
            ),
          ],
        ),
      );
    }

    // Build sections
    final managedServers = servers.where((s) => s.isManaged).toList();
    final externalServers = servers.where((s) => !s.isManaged).toList();

    // Clamp selected index
    if (servers.isNotEmpty && _selectedIndex >= servers.length) {
      _selectedIndex = servers.length - 1;
    }

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event, servers);
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.base.surface,
        ),
        child: Row(
          children: [
            // Left border separator
            Container(
              width: 1,
              decoration: BoxDecoration(
                color: theme.base.outline.withOpacity(TextOpacity.separator),
              ),
            ),
            // Main content
            SizedBox(
              width: component.width - 1,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: Row(
                    children: [
                      Text(
                        'MCP Servers',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.base.onSurface,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${mcpState.connectedServers.length}/${servers.length}',
                        style: TextStyle(
                          color: theme.base.onSurface
                              .withOpacity(TextOpacity.tertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: theme.base.outline),

                // Server list
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      // Managed section
                      if (managedServers.isNotEmpty) ...[
                        _SectionHeader(title: 'MANAGED'),
                        for (int i = 0; i < managedServers.length; i++)
                          _McpServerItem(
                            server: managedServers[i],
                            isSelected: component.focused &&
                                _getGlobalIndex(managedServers[i], servers) ==
                                    _selectedIndex,
                            showTools: _showTools &&
                                _getGlobalIndex(managedServers[i], servers) ==
                                    _selectedIndex,
                          ),
                      ],
                      // External section
                      if (externalServers.isNotEmpty) ...[
                        _SectionHeader(title: 'CONFIGURED'),
                        for (int i = 0; i < externalServers.length; i++)
                          _McpServerItem(
                            server: externalServers[i],
                            isSelected: component.focused &&
                                _getGlobalIndex(externalServers[i], servers) ==
                                    _selectedIndex,
                            showTools: _showTools &&
                                _getGlobalIndex(externalServers[i], servers) ==
                                    _selectedIndex,
                          ),
                      ],
                      // Empty state
                      if (servers.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(1),
                          child: Text(
                            'No MCP servers',
                            style: TextStyle(
                              color: theme.base.onSurface
                                  .withOpacity(TextOpacity.tertiary),
                            ),
                          ),
                        ),
                      // Skills section
                      if (mcpState.skills.isNotEmpty) ...[
                        _SectionHeader(title: 'SKILLS'),
                        for (final skill in mcpState.skills)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 1),
                            child: Text(
                              '◆ $skill',
                              style: TextStyle(
                                color: theme.base.onSurface
                                    .withOpacity(TextOpacity.secondary),
                              ),
                            ),
                          ),
                      ],
                      // Plugins section
                      if (mcpState.plugins.isNotEmpty) ...[
                        _SectionHeader(title: 'PLUGINS'),
                        for (final plugin in mcpState.plugins)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 1),
                            child: Text(
                              '▸ ${plugin['name'] ?? 'unknown'}',
                              style: TextStyle(
                                color: theme.base.onSurface
                                    .withOpacity(TextOpacity.secondary),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                // Footer with counts
                Divider(color: theme.base.outline),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mcpState.availableTools.length} tools',
                        style: TextStyle(
                          color: theme.base.onSurface
                              .withOpacity(TextOpacity.tertiary),
                        ),
                      ),
                      if (mcpState.model != null)
                        Text(
                          mcpState.model!,
                          style: TextStyle(
                            color: theme.base.onSurface
                                .withOpacity(TextOpacity.tertiary),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  int _getGlobalIndex(McpServerInfo server, List<McpServerInfo> allServers) {
    return allServers.indexOf(server);
  }
}

class _SectionHeader extends StatelessComponent {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 1, top: 1),
      child: Text(
        title,
        style: TextStyle(
          color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
        ),
      ),
    );
  }
}

class _McpServerItem extends StatelessComponent {
  final McpServerInfo server;
  final bool isSelected;
  final bool showTools;

  const _McpServerItem({
    required this.server,
    required this.isSelected,
    this.showTools = false,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Status indicator color
    final statusColor = switch (server.status) {
      McpServerStatus.connected => theme.status.idle,
      McpServerStatus.error => theme.status.error,
      McpServerStatus.stopped =>
        theme.base.onSurface.withOpacity(TextOpacity.disabled),
      McpServerStatus.unknown =>
        theme.base.onSurface.withOpacity(TextOpacity.tertiary),
    };

    // Status indicator symbol
    final statusSymbol = switch (server.status) {
      McpServerStatus.connected => '●',
      McpServerStatus.error => '✗',
      McpServerStatus.stopped => '○',
      McpServerStatus.unknown => '?',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected ? theme.base.surface : null,
          ),
          child: Row(
            children: [
              // Status indicator
              Text(statusSymbol, style: TextStyle(color: statusColor)),
              SizedBox(width: 1),
              // Server name
              Expanded(
                child: Text(
                  server.name,
                  style: TextStyle(
                    color: theme.base.onSurface.withOpacity(
                      server.status == McpServerStatus.connected
                          ? TextOpacity.primary
                          : TextOpacity.secondary,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Tool count
              if (server.tools.isNotEmpty)
                Text(
                  '${server.tools.length}',
                  style: TextStyle(
                    color:
                        theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                  ),
                ),
            ],
          ),
        ),
        // Error message
        if (server.status == McpServerStatus.error &&
            server.errorMessage != null)
          Padding(
            padding: EdgeInsets.only(left: 3),
            child: Text(
              server.errorMessage!,
              style: TextStyle(
                color: theme.status.error.withOpacity(TextOpacity.secondary),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // Tools list (when expanded)
        if (showTools && server.tools.isNotEmpty)
          ...server.tools.take(10).map(
                (tool) => Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Text(
                    '└ $tool',
                    style: TextStyle(
                      color:
                          theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        if (showTools && server.tools.length > 10)
          Padding(
            padding: EdgeInsets.only(left: 3),
            child: Text(
              '  +${server.tools.length - 10} more',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ),
      ],
    );
  }
}
