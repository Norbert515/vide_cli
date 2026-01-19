import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/settings/components/section_header.dart';

/// Server settings section - start/stop embedded HTTP server.
class ServerSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const ServerSection({required this.focused, required this.onExit, super.key});

  @override
  State<ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<ServerSection> {
  int _selectedIndex = 0;
  String _portInput = '8080';
  bool _editingPort = false;

  // Items: [0] = Start/Stop toggle, [1] = Port input
  int get _totalItems => 2;

  void _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return;

    if (_editingPort) {
      _handlePortEditing(event);
      return;
    }

    if (event.logicalKey == LogicalKey.arrowUp || event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
    } else if (event.logicalKey == LogicalKey.arrowDown || event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalItems - 1) {
        setState(() => _selectedIndex++);
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft || event.logicalKey == LogicalKey.escape) {
      component.onExit();
    } else if (event.logicalKey == LogicalKey.enter || event.logicalKey == LogicalKey.space) {
      _activateCurrentItem();
    }
  }

  void _handlePortEditing(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape || event.logicalKey == LogicalKey.enter) {
      setState(() => _editingPort = false);
    } else if (event.logicalKey == LogicalKey.backspace) {
      if (_portInput.isNotEmpty) {
        setState(() => _portInput = _portInput.substring(0, _portInput.length - 1));
      }
    } else if (event.character != null && RegExp(r'^\d$').hasMatch(event.character!)) {
      if (_portInput.length < 5) {
        setState(() => _portInput += event.character!);
      }
    }
  }

  void _activateCurrentItem() {
    if (_selectedIndex == 0) {
      // Toggle server
      final serverNotifier = context.read(embeddedServerProvider.notifier);
      final serverState = context.read(embeddedServerProvider);

      if (serverState.isRunning) {
        serverNotifier.stop();
      } else {
        final port = int.tryParse(_portInput) ?? 8080;
        serverNotifier.start(port: port);
      }
    } else if (_selectedIndex == 1) {
      // Edit port
      final serverState = context.read(embeddedServerProvider);
      if (!serverState.isRunning) {
        setState(() => _editingPort = true);
      }
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final serverState = context.watch(embeddedServerProvider);
    final session = context.watch(currentVideSessionProvider);
    final hasSession = session != null;

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
            SectionHeader(title: 'Embedded Server'),
            SizedBox(height: 2),

            Text(
              'Run an HTTP/WebSocket server to control Vide from external apps.',
              style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
            ),
            SizedBox(height: 2),

            if (!hasSession) ...[
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.base.error.withOpacity(0.1),
                  border: BoxBorder.all(color: theme.base.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text('! ', style: TextStyle(color: theme.base.error)),
                    Text(
                      'Start a session first to enable the server',
                      style: TextStyle(color: theme.base.error),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2),
            ],

            // Server toggle
            _ServerToggleItem(
              isRunning: serverState.isRunning,
              isStarting: serverState.isStarting,
              isSelected: component.focused && _selectedIndex == 0,
              enabled: hasSession,
              onTap: () {
                setState(() => _selectedIndex = 0);
                if (hasSession) _activateCurrentItem();
              },
            ),

            SizedBox(height: 1),

            // Port input
            _PortInputItem(
              port: _portInput,
              isEditing: _editingPort,
              isSelected: component.focused && _selectedIndex == 1,
              enabled: hasSession && !serverState.isRunning,
              onTap: () {
                setState(() => _selectedIndex = 1);
                if (hasSession && !serverState.isRunning) {
                  _activateCurrentItem();
                }
              },
            ),

            if (serverState.error != null) ...[
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.base.error.withOpacity(0.1),
                  border: BoxBorder.all(color: theme.base.error.withOpacity(0.3)),
                ),
                child: Text(
                  'Error: ${serverState.error}',
                  style: TextStyle(color: theme.base.error),
                ),
              ),
            ],

            if (serverState.isRunning) ...[
              SizedBox(height: 3),
              SectionHeader(title: 'Server URLs'),
              SizedBox(height: 1),
              _UrlDisplay(label: 'HTTP', url: serverState.url!),
              SizedBox(height: 1),
              _UrlDisplay(label: 'WebSocket', url: serverState.wsUrl!),
              SizedBox(height: 2),
              Text(
                'Tip: Use the WebSocket endpoint for real-time event streaming',
                style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.tertiary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServerToggleItem extends StatelessComponent {
  final bool isRunning;
  final bool isStarting;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ServerToggleItem({
    required this.isRunning,
    required this.isStarting,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    String statusText;
    Color statusColor;
    if (isStarting) {
      statusText = 'Starting...';
      statusColor = theme.base.onSurface.withOpacity(TextOpacity.secondary);
    } else if (isRunning) {
      statusText = 'Running';
      statusColor = theme.base.primary;
    } else {
      statusText = 'Stopped';
      statusColor = theme.base.onSurface.withOpacity(TextOpacity.tertiary);
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                'Server',
                style: TextStyle(
                  color: enabled
                      ? theme.base.onSurface
                      : theme.base.onSurface.withOpacity(TextOpacity.disabled),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isRunning ? theme.base.primary.withOpacity(0.2) : null,
                border: BoxBorder.all(
                  color: statusColor.withOpacity(0.5),
                ),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor),
              ),
            ),
            SizedBox(width: 2),
            Text(
              isRunning ? '[Enter to stop]' : '[Enter to start]',
              style: TextStyle(
                color: enabled
                    ? theme.base.onSurface.withOpacity(TextOpacity.tertiary)
                    : theme.base.onSurface.withOpacity(TextOpacity.disabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortInputItem extends StatelessComponent {
  final String port;
  final bool isEditing;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _PortInputItem({
    required this.port,
    required this.isEditing,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                'Port',
                style: TextStyle(
                  color: enabled
                      ? theme.base.onSurface
                      : theme.base.onSurface.withOpacity(TextOpacity.disabled),
                ),
              ),
            ),
            Container(
              width: 8,
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isEditing ? theme.base.surface : null,
                border: BoxBorder.all(
                  color: isEditing
                      ? theme.base.primary
                      : theme.base.outline.withOpacity(0.5),
                ),
              ),
              child: Text(
                isEditing ? '${port}_' : port,
                style: TextStyle(
                  color: enabled
                      ? theme.base.onSurface
                      : theme.base.onSurface.withOpacity(TextOpacity.disabled),
                ),
              ),
            ),
            SizedBox(width: 2),
            if (!enabled)
              Text(
                '(stop server to change)',
                style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.disabled)),
              ),
          ],
        ),
      ),
    );
  }
}

class _UrlDisplay extends StatelessComponent {
  final String label;
  final String url;

  const _UrlDisplay({required this.label, required this.url});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text(
            '$label:',
            style: TextStyle(color: theme.base.onSurface.withOpacity(TextOpacity.secondary)),
          ),
        ),
        Text(
          url,
          style: TextStyle(color: theme.base.primary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
