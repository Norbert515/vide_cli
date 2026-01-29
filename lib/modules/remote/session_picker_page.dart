import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/remote/remote_vide_session.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_daemon/vide_daemon.dart';

/// Page for listing and selecting sessions from a daemon.
class SessionPickerPage extends StatefulComponent {
  const SessionPickerPage({super.key});

  @override
  State<SessionPickerPage> createState() => _SessionPickerPageState();
}

class _SessionPickerPageState extends State<SessionPickerPage> {
  List<SessionSummary>? _sessions;
  String? _error;
  bool _loading = true;
  int _selectedIndex = 0;
  DaemonClient? _client;
  StreamSubscription<DaemonEvent>? _eventSubscription;

  /// When true, show the create session input instead of the session list.
  bool _showCreateInput = false;
  final _createInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _client?.close();
    _createInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final remoteConfig = context.read(remoteConfigProvider);
    if (remoteConfig == null) {
      setState(() {
        _error = 'No remote configuration provided';
        _loading = false;
      });
      return;
    }

    _client = DaemonClient(
      host: remoteConfig.host,
      port: remoteConfig.port,
      authToken: remoteConfig.authToken,
    );

    try {
      // Check if daemon is healthy
      final healthy = await _client!.isHealthy();
      if (!healthy) {
        setState(() {
          _error = 'Daemon is not responding at ${remoteConfig.daemonUrl}';
          _loading = false;
        });
        return;
      }

      // Load sessions
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

  bool _handleKeyEvent(KeyboardEvent event) {
    if (_loading) return false;

    // Handle create input mode separately (TextField handles most input)
    if (_showCreateInput) {
      if (event.logicalKey == LogicalKey.escape) {
        setState(() {
          _showCreateInput = false;
          _createInputController.clear();
        });
        return true;
      }
      // Let the TextField handle other keys
      return false;
    }

    if (_error != null) {
      // Handle error state keys
      if (event.logicalKey == LogicalKey.keyR) {
        setState(() {
          _loading = true;
          _error = null;
        });
        _loadSessions();
        return true;
      }
      if (event.logicalKey == LogicalKey.keyQ ||
          event.logicalKey == LogicalKey.escape) {
        Navigator.of(context).pop();
        return true;
      }
      return false;
    }

    final sessions = _sessions ?? [];
    // +1 for "Create new session" option
    final totalItems = sessions.length + 1;

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + totalItems) % totalItems;
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % totalItems;
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      _handleSelect();
      return true;
    }
    if (event.logicalKey == LogicalKey.escape ||
        event.logicalKey == LogicalKey.keyQ) {
      Navigator.of(context).pop();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyR) {
      _refreshSessions();
      return true;
    }

    return false;
  }

  Future<void> _handleSelect() async {
    final sessions = _sessions ?? [];

    if (_selectedIndex == sessions.length) {
      // Show create session input
      setState(() {
        _showCreateInput = true;
      });
    } else {
      // Connect to existing session
      final session = sessions[_selectedIndex];
      await _connectToSession(session.sessionId);
    }
  }

  Future<void> _submitCreateSession() async {
    final message = _createInputController.text.trim();
    if (message.isEmpty) return;

    await _createNewSession(message);
  }

  Future<void> _createNewSession(String initialMessage) async {
    final remoteConfig = context.read(remoteConfigProvider);
    if (_client == null || remoteConfig == null) return;

    setState(() {
      _loading = true;
      _showCreateInput = false;
    });

    try {
      final response = await _client!.createSession(
        initialMessage: initialMessage,
        workingDirectory: Directory.current.path,
        permissionMode: 'ask',
      );

      await _connectToSession(response.sessionId);
    } catch (e) {
      setState(() {
        _error = 'Failed to create session: $e';
        _loading = false;
        _createInputController.clear();
      });
    }
  }

  Future<void> _connectToSession(String sessionId) async {
    // Get full session details to get the wsUrl
    try {
      final details = await _client!.getSession(sessionId);

      // Create and connect the remote session
      final remoteSession = RemoteVideSession(
        sessionId: sessionId,
        wsUrl: details.wsUrl,
        authToken: context.read(remoteConfigProvider)?.authToken,
      );

      await remoteSession.connect();

      // Store in provider for the rest of the app
      context.read(remoteVideSessionProvider.notifier).state = remoteSession;

      // Navigate to the network execution page
      // The page will detect we're in remote mode via the provider
      NetworkExecutionPage.push(context, sessionId);
    } catch (e) {
      setState(() {
        _error = 'Failed to connect to session: $e';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final remoteConfig = context.watch(remoteConfigProvider);

    return Focusable(
      focused: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Connect to Daemon',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.base.primary,
              ),
            ),
            Text(
              remoteConfig != null
                  ? '${remoteConfig.host}:${remoteConfig.port}'
                  : 'No daemon configured',
              style: TextStyle(color: theme.base.onSurface.withOpacity(0.6)),
            ),
            SizedBox(height: 1),

            // Content
            if (_loading)
              Text(
                'Loading sessions...',
                style: TextStyle(color: theme.base.onSurface.withOpacity(0.6)),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.base.error,
                    ),
                  ),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Press [r] to retry, [q] to quit',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              )
            else if (_showCreateInput)
              _buildCreateInput(theme)
            else
              _buildSessionList(theme),

            // Footer
            Spacer(),
            Divider(),
            Text(
              _showCreateInput
                  ? '⏎ Create session  Esc Cancel'
                  : '↑↓ Navigate  ⏎ Select  r Refresh  q Quit',
              style: TextStyle(color: theme.base.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Component _buildSessionList(VideThemeData theme) {
    final sessions = _sessions ?? [];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sessions list
          for (var i = 0; i < sessions.length; i++)
            _buildSessionItem(sessions[i], i, theme),

          // Create new session option
          _buildCreateNewItem(sessions.length, theme),
        ],
      ),
    );
  }

  Component _buildSessionItem(
    SessionSummary session,
    int index,
    VideThemeData theme,
  ) {
    final isSelected = index == _selectedIndex;
    final stateColor = switch (session.state) {
      SessionProcessState.ready => theme.status.idle, // Green
      SessionProcessState.starting => theme.status.working, // Yellow/orange
      SessionProcessState.error => theme.base.error,
      SessionProcessState.stopping => theme.base.onSurface.withOpacity(0.5),
    };

    return Container(
      color: isSelected ? theme.base.surface : null,
      child: Row(
        children: [
          Text(
            isSelected ? '▶ ' : '  ',
            style: TextStyle(color: theme.base.primary),
          ),
          Text('● ', style: TextStyle(color: stateColor)),
          Expanded(
            child: Text(
              session.goal ?? session.workingDirectory,
              style: TextStyle(
                color: isSelected
                    ? theme.base.onSurface
                    : theme.base.onSurface.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          ),
          Text(
            '${session.agentCount} agents',
            style: TextStyle(color: theme.base.onSurface.withOpacity(0.5)),
          ),
          SizedBox(width: 2),
          Text(
            _formatTime(session.createdAt),
            style: TextStyle(color: theme.base.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Component _buildCreateNewItem(int index, VideThemeData theme) {
    final isSelected = index == _selectedIndex;

    return Container(
      color: isSelected ? theme.base.surface : null,
      child: Row(
        children: [
          Text(
            isSelected ? '▶ ' : '  ',
            style: TextStyle(color: theme.base.primary),
          ),
          Text('+ ', style: TextStyle(color: theme.status.idle)),
          Text(
            'Create new session',
            style: TextStyle(
              color: isSelected
                  ? theme.base.onSurface
                  : theme.base.onSurface.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Component _buildCreateInput(VideThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.base.primary,
          ),
        ),
        SizedBox(height: 1),
        Text(
          'Enter your initial message:',
          style: TextStyle(color: theme.base.onSurface.withOpacity(0.7)),
        ),
        SizedBox(height: 1),
        TextField(
          controller: _createInputController,
          focused: true,
          onSubmitted: (_) => _submitCreateSession(),
          placeholder: 'Describe your goal...',
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
