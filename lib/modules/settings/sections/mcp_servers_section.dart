import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

/// MCP Servers settings content wrapped in a Servers card.
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
  ClaudeSettingsManager? _settingsManager;

  /// Server names from .mcp.json config.
  List<String> _serverNames = [];

  /// Live status by server name (populated when a session is available).
  Map<String, VideMcpServerInfo> _liveStatus = {};
  StreamSubscription<List<VideMcpServerInfo>>? _mcpStreamSub;

  List<String> get _filteredNames {
    return _serverNames.where((s) => !s.startsWith('vide-')).toList();
  }

  @override
  void initState() {
    super.initState();
    _settingsManager = ClaudeSettingsManager(
      projectRoot: Directory.current.path,
    );
    _loadServers();
  }

  @override
  void dispose() {
    _mcpStreamSub?.cancel();
    super.dispose();
  }

  void _loadServers() {
    final mcpJson =
        _settingsManager?.readMcpJsonSync() ?? const McpJsonConfig();
    setState(() {
      _serverNames = mcpJson.serverNames.toList();
    });

    // Best-effort: try to get live status from a running session.
    _tryLiveStatus();
  }

  void _tryLiveStatus() {
    final session = context.read(currentVideSessionProvider) ??
        context.read(pendingSessionProvider);
    if (session == null) return;

    session.getMcpServers().then((servers) {
      if (servers.isNotEmpty && mounted) {
        setState(() {
          _liveStatus = {for (final s in servers) s.name: s};
        });
      }
    }).catchError((_) {});

    _mcpStreamSub = session.mcpServersStream().listen((servers) {
      if (servers.isNotEmpty && mounted) {
        setState(() {
          _liveStatus = {for (final s in servers) s.name: s};
        });
      }
    });
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return false;
    final names = _filteredNames;
    if (names.isEmpty) {
      if (event.logicalKey == LogicalKey.arrowLeft ||
          event.logicalKey == LogicalKey.escape) {
        component.onExit();
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < names.length - 1) {
        setState(() => _selectedIndex++);
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
      return true;
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _toggleServer(_selectedIndex);
      return true;
    }

    return false;
  }

  Future<void> _toggleServer(int index) async {
    final names = _filteredNames;
    if (index >= names.length) return;

    final name = names[index];
    final isEnabled = _settingsManager?.isMcpServerEnabled(name) ?? false;

    if (isEnabled) {
      await _settingsManager?.disableMcpServer(name);
    } else {
      await _settingsManager?.enableMcpServer(name);
    }

    setState(() {}); // Rebuild to show new state
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final names = _filteredNames;

    // Clamp selected index
    if (names.isNotEmpty && _selectedIndex >= names.length) {
      _selectedIndex = names.length - 1;
    }

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              title: 'Servers',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (names.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        'No MCP servers configured',
                        style: TextStyle(
                          color: theme.base.onSurface.withOpacity(
                            TextOpacity.tertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    for (int index = 0; index < names.length; index++)
                      _McpServerItem(
                        name: names[index],
                        isEnabled:
                            _settingsManager?.isMcpServerEnabled(
                              names[index],
                            ) ??
                            false,
                        liveStatus: _liveStatus[names[index]],
                        isSelected:
                            component.focused && index == _selectedIndex,
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          _toggleServer(index);
                        },
                      ),
                ],
              ),
            ),

            SizedBox(height: 1),

            Padding(
              padding: EdgeInsets.only(left: 1),
              child: Text(
                'Changes take effect on next session',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual MCP server item in the list - compact single-line format.
class _McpServerItem extends StatelessComponent {
  final String name;
  final bool isEnabled;
  final VideMcpServerInfo? liveStatus;
  final bool isSelected;
  final VoidCallback onTap;

  const _McpServerItem({
    required this.name,
    required this.isEnabled,
    required this.liveStatus,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Derive display status: prefer live data, fall back to enabled/disabled.
    final (statusText, statusColor) = _resolveStatus(theme);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsToggle(value: isEnabled, focused: isSelected),
                SizedBox(width: 1),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        isEnabled
                            ? TextOpacity.primary
                            : TextOpacity.secondary,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(statusText, style: TextStyle(color: statusColor)),
              ],
            ),
            if (liveStatus?.error != null)
              Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  liveStatus!.error!,
                  style: TextStyle(
                    color: theme.status.error.withOpacity(
                      TextOpacity.secondary,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, Color) _resolveStatus(VideThemeData theme) {
    final live = liveStatus;

    // If we have live connection data, use it.
    if (live != null && live.status != VideMcpServerStatus.disconnected) {
      return switch (live.status) {
        VideMcpServerStatus.connected => ('connected', theme.status.idle),
        VideMcpServerStatus.failed => ('failed', theme.status.error),
        VideMcpServerStatus.connecting => (
          'connecting',
          theme.base.onSurface.withOpacity(TextOpacity.secondary),
        ),
        VideMcpServerStatus.disconnected => ('', const Color(0)), // unreachable
      };
    }

    // No live data — derive from settings enabled/disabled state.
    if (isEnabled) {
      return (
        'enabled',
        theme.base.onSurface.withOpacity(TextOpacity.secondary),
      );
    }
    return (
      'disabled',
      theme.base.onSurface.withOpacity(TextOpacity.disabled),
    );
  }
}
