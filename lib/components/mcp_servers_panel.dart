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
    // Filter out internal vide-* MCP servers
    final servers = (mcpStatus?.servers ?? [])
        .where((s) => !s.name.startsWith('vide-'))
        .toList();

    if (!component.expanded) {
      // Collapsed view - just show count (filtered)
      final connectedCount = servers.where((s) => s.status == McpServerStatus.connected).length;
      final hasErrors = servers.any((s) => s.status == McpServerStatus.failed);
      return SizedBox(
        width: 3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Top padding to align with main content
            SizedBox(height: 1),
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
                  // Top padding to align with main content
                  SizedBox(height: 1),

                  // Header
                  Padding(
                    padding: EdgeInsets.only(left: 1),
                    child: Text(
                      'MCP Servers',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
                      ),
                    ),
                  ),

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

                        // Servers
                        if (servers.isNotEmpty) ...[
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

                  // Navigation hint at bottom (matching left sidebar)
                  if (component.focused)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        '← to exit',
                        style: TextStyle(
                          color: theme.base.onSurface.withOpacity(TextOpacity.disabled),
                        ),
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
          decoration: isSelected
              ? BoxDecoration(color: theme.base.primary.withOpacity(0.3))
              : null,
          child: Padding(
            padding: EdgeInsets.only(left: 1),
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
