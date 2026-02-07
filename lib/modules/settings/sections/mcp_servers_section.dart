import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

/// MCP Servers settings content.
class McpServersSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const McpServersSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<McpServersSection> createState() => _McpServersSectionState();
}

class _McpServersSectionState extends State<McpServersSection> {
  int _selectedIndex = 0;
  McpStatusResponse? _mcpStatus;
  StreamSubscription<McpStatusResponse>? _subscription;
  ClaudeSettingsManager? _settingsManager;

  List<McpServerStatusInfo> get _filteredServers {
    return (_mcpStatus?.servers ?? [])
        .where((s) => !s.name.startsWith('vide-'))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initMcpStatus();
    _initSettingsManager();
  }

  void _initMcpStatus() {
    final initialClient = context.read(initialClaudeClientProvider);
    _mcpStatus = initialClient.mcpStatus;
    _subscription = initialClient.mcpStatusStream.listen((status) {
      setState(() => _mcpStatus = status);
    });
  }

  void _initSettingsManager() {
    _settingsManager = ClaudeSettingsManager(
      projectRoot: Directory.current.path,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return;
    final servers = _filteredServers;
    if (servers.isEmpty) {
      if (event.logicalKey == LogicalKey.arrowLeft ||
          event.logicalKey == LogicalKey.escape) {
        component.onExit();
      }
      return;
    }

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < servers.length - 1) {
        setState(() => _selectedIndex++);
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _toggleServer(_selectedIndex);
    }
  }

  Future<void> _toggleServer(int index) async {
    final servers = _filteredServers;
    if (index >= servers.length) return;

    final server = servers[index];
    final isEnabled =
        _settingsManager?.isMcpServerEnabled(server.name) ?? false;

    if (isEnabled) {
      await _settingsManager?.disableMcpServer(server.name);
    } else {
      await _settingsManager?.enableMcpServer(server.name);
    }

    setState(() {}); // Rebuild to show new state
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final servers = _filteredServers;

    // Clamp selected index
    if (servers.isNotEmpty && _selectedIndex >= servers.length) {
      _selectedIndex = servers.length - 1;
    }

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'MCP Servers'),
            SizedBox(height: 1),
            Text(
              'Enable or disable MCP server connections',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 2),

            // Server list
            if (_mcpStatus == null)
              Text(
                'Loading MCP servers...',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              )
            else if (servers.isEmpty)
              Text(
                'No MCP servers configured',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    final isEnabled =
                        _settingsManager?.isMcpServerEnabled(server.name) ??
                        false;

                    return _McpServerItem(
                      server: server,
                      isEnabled: isEnabled,
                      isSelected: component.focused && index == _selectedIndex,
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        _toggleServer(index);
                      },
                    );
                  },
                ),
              ),

            SizedBox(height: 2),
            Text(
              'Changes take effect on next session',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual MCP server item in the list.
class _McpServerItem extends StatelessComponent {
  final McpServerStatusInfo server;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback onTap;

  const _McpServerItem({
    required this.server,
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Status text and color
    final (statusText, statusColor) = switch (server.status) {
      McpServerStatus.connected => ('connected', theme.status.idle),
      McpServerStatus.failed => ('failed', theme.status.error),
      McpServerStatus.connecting => (
        'connecting',
        theme.base.onSurface.withOpacity(TextOpacity.secondary),
      ),
      McpServerStatus.disconnected => (
        'disabled',
        theme.base.onSurface.withOpacity(TextOpacity.disabled),
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
            ),
            child: Row(
              children: [
                // Enable/disable checkbox
                SettingsToggle(value: isEnabled, focused: isSelected),
                SizedBox(width: 2),
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
                // Status text on the right
                Text(statusText, style: TextStyle(color: statusColor)),
              ],
            ),
          ),
          // Error message
          if (server.error != null)
            Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text(
                server.error!,
                style: TextStyle(
                  color: theme.status.error.withOpacity(TextOpacity.secondary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
