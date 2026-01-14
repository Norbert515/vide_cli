import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_client/vide_client.dart';

/// Page for viewing a remote vide session.
///
/// Connects to a remote vide server via WebSocket and displays
/// the session events in a read-only view.
class RemoteSessionPage extends StatefulComponent {
  final String serverUri;

  const RemoteSessionPage({required this.serverUri, super.key});

  @override
  State<RemoteSessionPage> createState() => _RemoteSessionPageState();
}

class _RemoteSessionPageState extends State<RemoteSessionPage> {
  WebSocketSessionTransport? _transport;
  StreamSubscription<SessionEvent>? _eventSubscription;
  StreamSubscription<ConnectionState>? _connectionSubscription;

  ConnectionState _connectionState = ConnectionState.disconnected;
  SessionInfo? _sessionInfo;
  final List<SessionEvent> _events = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = component.serverUri.split(':').first;
    final port = int.tryParse(component.serverUri.split(':').last) ?? 8547;

    // For now, assume a single session endpoint
    // The server returns session info on connection
    final wsUri = Uri.parse('ws://$host:$port/ws');

    _transport = WebSocketSessionTransport(
      uri: wsUri,
      sessionId: 'remote', // Will be updated on ConnectedEvent
    );

    _eventSubscription = _transport!.events.listen(
      _onEvent,
      onError: _onError,
    );

    _connectionSubscription = _transport!.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });

    try {
      await _transport!.connect();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to connect: $e';
        });
      }
    }
  }

  void _disconnect() {
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    _transport?.close();
  }

  void _onEvent(SessionEvent event) {
    if (!mounted) return;

    setState(() {
      _events.add(event);

      if (event is ConnectedEvent) {
        _sessionInfo = event.sessionInfo;
      }
    });
  }

  void _onError(Object error) {
    if (!mounted) return;

    setState(() {
      _error = error.toString();
    });
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        children: [
          // Header
          _buildHeader(theme),
          SizedBox(height: 1),
          // Connection status
          _buildConnectionStatus(theme),
          SizedBox(height: 1),
          // Error display
          if (_error != null) ...[
            Container(
              padding: EdgeInsets.all(1),
              decoration: BoxDecoration(color: theme.base.error),
              child: Text(
                _error!,
                style: TextStyle(color: theme.base.onError),
              ),
            ),
            SizedBox(height: 1),
          ],
          // Event list
          Expanded(child: _buildEventList(theme)),
          // Help text
          SizedBox(height: 1),
          Text(
            'Press Ctrl+C to disconnect and exit',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  Component _buildHeader(VideThemeData theme) {
    final sessionId = _sessionInfo?.sessionId ?? 'Connecting...';
    final goal = _sessionInfo?.goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Remote Session',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
            SizedBox(width: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: theme.base.primary),
              child: Text(
                'READ-ONLY',
                style: TextStyle(
                  color: theme.base.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1),
        Text(
          'Server: ${component.serverUri}',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
        Text(
          'Session: $sessionId',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
        if (goal != null)
          Text(
            'Goal: $goal',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
      ],
    );
  }

  Component _buildConnectionStatus(VideThemeData theme) {
    final (statusText, statusColor) = switch (_connectionState) {
      ConnectionState.disconnected => ('Disconnected', theme.base.error),
      ConnectionState.connecting => ('Connecting...', theme.base.warning),
      ConnectionState.connected => ('Connected', theme.base.success),
      ConnectionState.reconnecting => ('Reconnecting...', theme.base.warning),
    };

    return Row(
      children: [
        Text('Status: '),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: statusColor),
          child: Text(
            statusText,
            style: TextStyle(
              color: theme.base.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_sessionInfo != null) ...[
          SizedBox(width: 2),
          Text(
            '${_sessionInfo!.agents.length} agent(s)',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
        ],
      ],
    );
  }

  Component _buildEventList(VideThemeData theme) {
    if (_events.isEmpty) {
      return Center(
        child: Text(
          _connectionState == ConnectionState.connected
              ? 'Waiting for events...'
              : 'Connecting to remote session...',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
          ),
        ),
      );
    }

    return ListView(
      children: [
        for (final event in _events) _buildEventItem(theme, event),
      ],
    );
  }

  Component _buildEventItem(VideThemeData theme, SessionEvent event) {
    final (icon, description) = switch (event) {
      ConnectedEvent e => ('🔌', 'Connected to session ${e.sessionInfo.sessionId}'),
      MessageEvent e => (
          e.role == 'assistant' ? '🤖' : '👤',
          '${e.role}: ${_truncate(e.content, 60)}'
        ),
      ToolUseEvent e => ('🔧', 'Tool: ${e.toolName}'),
      ToolResultEvent e => ('📤', 'Tool result${e.isError ? ' (error)' : ''}'),
      PermissionRequestEvent e => ('🔒', 'Permission: ${e.toolName}'),
      AgentSpawnedEvent e => ('➕', 'Agent spawned: ${e.name}'),
      AgentTerminatedEvent e => ('➖', 'Agent terminated: ${e.terminatedAgentId}'),
      AgentStatusEvent e => ('📊', 'Agent status: ${e.status.name}'),
      ErrorEvent e => ('❌', 'Error: ${e.message}'),
      ClientJoinedEvent e => ('👋', 'Client joined: ${e.clientId}'),
      ClientLeftEvent e => ('👋', 'Client left: ${e.clientId}'),
      TurnCompleteEvent _ => ('✅', 'Turn complete'),
      PermissionTimeoutEvent e => ('⏰', 'Permission timeout: ${e.requestId}'),
      AbortedEvent _ => ('🛑', 'Aborted'),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: event is ErrorEvent
                    ? theme.base.error
                    : theme.base.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
