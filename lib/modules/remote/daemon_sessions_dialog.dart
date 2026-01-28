import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/remote/remote_vide_session.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_daemon/vide_daemon.dart';

/// A dialog for viewing and connecting to existing daemon sessions.
///
/// Shows a list of sessions running on the configured daemon.
/// Press 'd' from the home page to open this dialog when daemon mode is enabled.
class DaemonSessionsDialog extends StatefulComponent {
  const DaemonSessionsDialog({super.key});

  /// Shows the daemon sessions dialog.
  /// Returns true if a session was connected to, false otherwise.
  static Future<bool> show(BuildContext context) async {
    final result = await Navigator.of(context).showDialog<bool>(
      builder: (context) => const DaemonSessionsDialog(),
      barrierDismissible: true,
      width: 80,
      height: 24,
    );
    return result ?? false;
  }

  @override
  State<DaemonSessionsDialog> createState() => _DaemonSessionsDialogState();
}

class _DaemonSessionsDialogState extends State<DaemonSessionsDialog> {
  List<SessionSummary>? _sessions;
  String? _error;
  bool _loading = true;
  int _selectedIndex = 0;
  DaemonClient? _client;
  StreamSubscription<DaemonEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _client?.close();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    _client = DaemonClient(
      host: settings.daemonHost,
      port: settings.daemonPort,
    );

    try {
      final healthy = await _client!.isHealthy();
      if (!healthy) {
        setState(() {
          _error = 'Daemon not responding at ${settings.daemonHost}:${settings.daemonPort}';
          _loading = false;
        });
        return;
      }

      final sessions = await _client!.listSessions();

      // Subscribe to events for real-time updates
      _eventSubscription = _client!.connectEvents().listen((event) {
        if (event is SessionCreatedEvent || event is SessionStoppedEvent) {
          _refreshSessions();
        }
      });

      setState(() {
        _sessions = sessions;
        _loading = false;
        _selectedIndex = 0;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to connect: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshSessions() async {
    if (_client == null) return;

    try {
      final sessions = await _client!.listSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          if (_selectedIndex >= sessions.length) {
            _selectedIndex = sessions.isEmpty ? 0 : sessions.length - 1;
          }
        });
      }
    } catch (_) {
      // Ignore refresh errors
    }
  }

  void _handleKeyEvent(KeyboardEvent event) {
    if (_loading) return;

    if (_error != null) {
      if (event.logicalKey == LogicalKey.keyR) {
        setState(() {
          _loading = true;
          _error = null;
        });
        _loadSessions();
      } else if (event.logicalKey == LogicalKey.escape ||
          event.logicalKey == LogicalKey.keyQ) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    final sessions = _sessions ?? [];

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + sessions.length) % sessions.length;
      });
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % sessions.length;
      });
    } else if (event.logicalKey == LogicalKey.enter) {
      if (sessions.isNotEmpty) {
        _connectToSession(sessions[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKey.escape ||
        event.logicalKey == LogicalKey.keyQ) {
      Navigator.of(context).pop(false);
    } else if (event.logicalKey == LogicalKey.keyR) {
      _refreshSessions();
    }
  }

  Future<void> _connectToSession(SessionSummary session) async {
    try {
      final details = await _client!.getSession(session.sessionId);

      final remoteSession = RemoteVideSession(
        sessionId: session.sessionId,
        wsUrl: details.wsUrl,
      );

      await remoteSession.connect();

      // Store in provider
      context.read(remoteVideSessionProvider.notifier).state = remoteSession;

      // Close dialog and navigate
      Navigator.of(context).pop(true);

      // Navigate to execution page
      await NetworkExecutionPage.push(context, session.sessionId);
    } catch (e) {
      setState(() {
        _error = 'Failed to connect: $e';
      });
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        _handleKeyEvent(event);
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.base.surface,
          border: BoxBorder.all(color: theme.base.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                border: BoxBorder(
                  bottom: BorderSide(color: theme.base.outline.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Daemon Sessions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.base.primary,
                    ),
                  ),
                  Text(
                    ' - ${settings.daemonHost}:${settings.daemonPort}',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                    ),
                  ),
                  Expanded(child: SizedBox()),
                  Text(
                    '[Esc] Close',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(1),
                child: _buildContent(theme),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                border: BoxBorder(
                  top: BorderSide(color: theme.base.outline.withOpacity(0.3)),
                ),
              ),
              child: Text(
                _loading
                    ? 'Loading...'
                    : _error != null
                        ? '[r] Retry  [q] Close'
                        : '[j/k] Navigate  [Enter] Connect  [r] Refresh',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Component _buildContent(VideThemeData theme) {
    if (_loading) {
      return Center(
        child: Text(
          'Loading sessions...',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.base.error,
              ),
            ),
            SizedBox(height: 1),
            Text(
              _error!,
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
          ],
        ),
      );
    }

    final sessions = _sessions ?? [];

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No sessions running',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 1),
            Text(
              'Start a new session from the home page',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = index == _selectedIndex;

        final stateColor = switch (session.state) {
          SessionProcessState.ready => theme.status.idle,
          SessionProcessState.starting => theme.status.working,
          SessionProcessState.error => theme.base.error,
          SessionProcessState.stopping => theme.base.onSurface.withOpacity(0.5),
        };

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected ? theme.base.primary.withOpacity(0.15) : null,
          ),
          child: Row(
            children: [
              Text(
                isSelected ? '> ' : '  ',
                style: TextStyle(color: theme.base.primary),
              ),
              Text('● ', style: TextStyle(color: stateColor)),
              Expanded(
                child: Text(
                  session.goal ?? session.workingDirectory,
                  style: TextStyle(
                    color: isSelected
                        ? theme.base.onSurface
                        : theme.base.onSurface.withOpacity(TextOpacity.secondary),
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 2),
              Text(
                '${session.agentCount} agents',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
              SizedBox(width: 2),
              Text(
                _formatTime(session.createdAt),
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
