import 'dart:async';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart' hide McpServerStatus, McpServerInfo;

/// Panel displaying MCP servers and their status.
class McpServersPanel extends StatefulComponent {
  final InitialClaudeClient initialClient;
  final bool focused;
  final bool expanded;
  final double width;
  final VoidCallback? onExitLeft;

  const McpServersPanel({
    required this.initialClient,
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
  McpStatusResponse? _mcpStatus;
  StreamSubscription<McpStatusResponse>? _subscription;

  @override
  void initState() {
    super.initState();
    _mcpStatus = component.initialClient.mcpStatus;
    _subscription = component.initialClient.mcpStatusStream.listen((status) {
      setState(() => _mcpStatus = status);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleKeyEvent(KeyboardEvent event, int serverCount) {
    if (!component.focused) return;
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
    final mcpStatus = _mcpStatus;
    final servers = mcpStatus?.servers ?? [];

    if (!component.expanded) {
      // Collapsed view - just show count
      final connectedCount = mcpStatus?.connectedServers.length ?? 0;
      final hasErrors = mcpStatus?.failedServers.isNotEmpty ?? false;
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
              '$connectedCount',
              style: TextStyle(
                color: hasErrors ? theme.status.error : theme.status.idle,
              ),
            ),
          ],
        ),
      );
    }

    // Clamp selected index
    if (servers.isNotEmpty && _selectedIndex >= servers.length) {
      _selectedIndex = servers.length - 1;
    }

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event, servers.length);
        return true;
      },
      child: Container(
        decoration: BoxDecoration(color: theme.base.surface),
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
                          '${mcpStatus?.connectedServers.length ?? 0}/${servers.length}',
                          style: TextStyle(
                            color: theme.base.onSurface
                                .withOpacity(TextOpacity.tertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: theme.base.outline),

                  // Content
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      children: [
                        // Loading state
                        if (mcpStatus == null)
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Text(
                              'Loading...',
                              style: TextStyle(
                                color: theme.base.onSurface
                                    .withOpacity(TextOpacity.tertiary),
                              ),
                            ),
                          ),

                        // Servers section
                        if (servers.isNotEmpty) ...[
                          _SectionHeader(title: 'SERVERS'),
                          for (int i = 0; i < servers.length; i++)
                            _McpServerItem(
                              server: servers[i],
                              isSelected: component.focused && i == _selectedIndex,
                              showTools: _showTools && i == _selectedIndex,
                            ),
                        ],

                        // Empty state
                        if (mcpStatus != null && servers.isEmpty)
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
  final McpServerStatusInfo server;
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
      McpServerStatus.failed => theme.status.error,
      McpServerStatus.connecting =>
        theme.base.onSurface.withOpacity(TextOpacity.secondary),
      McpServerStatus.disconnected =>
        theme.base.onSurface.withOpacity(TextOpacity.disabled),
    };

    // Status indicator symbol
    final statusSymbol = switch (server.status) {
      McpServerStatus.connected => '●',
      McpServerStatus.failed => '✗',
      McpServerStatus.connecting => '◐',
      McpServerStatus.disconnected => '○',
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
            ],
          ),
        ),
        // Error message
        if (server.error != null)
          Padding(
            padding: EdgeInsets.only(left: 3),
            child: Text(
              server.error!,
              style: TextStyle(
                color: theme.status.error.withOpacity(TextOpacity.secondary),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
