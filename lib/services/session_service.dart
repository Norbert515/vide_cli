/// Session service for managing local and remote vide sessions.
///
/// This service abstracts over local (in-process) and remote (WebSocket)
/// session modes, providing a unified API for the TUI.
import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';

/// The current mode of the session service.
enum SessionMode {
  /// Running locally with in-process transport.
  local,

  /// Connected to a remote vide server.
  remote,
}

/// State of the remote access server.
class RemoteAccessState {
  /// Whether remote access is enabled.
  final bool isEnabled;

  /// Server info (address, port) when enabled.
  final ServerInfo? serverInfo;

  /// Currently connected remote clients.
  final List<ConnectedClient> clients;

  const RemoteAccessState({
    this.isEnabled = false,
    this.serverInfo,
    this.clients = const [],
  });

  RemoteAccessState copyWith({
    bool? isEnabled,
    ServerInfo? serverInfo,
    List<ConnectedClient>? clients,
  }) {
    return RemoteAccessState(
      isEnabled: isEnabled ?? this.isEnabled,
      serverInfo: serverInfo ?? this.serverInfo,
      clients: clients ?? this.clients,
    );
  }
}

/// Service for managing vide sessions with local/remote support.
///
/// In local mode:
/// - Uses DirectSessionTransport (in-process)
/// - Can optionally enable EmbeddedServer for remote clients to connect
///
/// In remote mode:
/// - Uses WebSocketSessionTransport
/// - Connects to an existing vide server
class SessionService {
  SessionService({
    required ProviderContainer container,
  }) : _container = container;

  final ProviderContainer _container;

  /// Current session mode.
  SessionMode _mode = SessionMode.local;

  /// The embedded server (only in local mode when remote access is enabled).
  EmbeddedServer? _embeddedServer;

  /// Remote access state.
  RemoteAccessState _remoteAccessState = const RemoteAccessState();

  /// Stream controller for remote access state changes.
  final _remoteAccessController =
      StreamController<RemoteAccessState>.broadcast();

  /// Stream controller for join requests.
  final _joinRequestController = StreamController<JoinRequest>.broadcast();

  /// Current session mode.
  SessionMode get mode => _mode;

  /// Whether remote access is enabled (local mode only).
  bool get isRemoteAccessEnabled => _remoteAccessState.isEnabled;

  /// Remote access state.
  RemoteAccessState get remoteAccessState => _remoteAccessState;

  /// Stream of remote access state changes.
  Stream<RemoteAccessState> get remoteAccessStateStream =>
      _remoteAccessController.stream;

  /// Stream of join requests from remote clients.
  Stream<JoinRequest> get joinRequests => _joinRequestController.stream;

  /// Whether the service is in local mode.
  bool get isLocalMode => _mode == SessionMode.local;

  /// Whether the service is in remote mode.
  bool get isRemoteMode => _mode == SessionMode.remote;

  /// Enable remote access for the current session.
  ///
  /// This starts an embedded HTTP/WebSocket server that remote clients
  /// can connect to. Returns the server info (address, port).
  ///
  /// Only works in local mode.
  Future<ServerInfo> enableRemoteAccess({
    required String sessionId,
    int? port,
  }) async {
    if (_mode != SessionMode.local) {
      throw StateError('Remote access can only be enabled in local mode');
    }

    if (_embeddedServer != null) {
      throw StateError('Remote access is already enabled');
    }

    _embeddedServer = EmbeddedServer(
      container: _container,
      sessionId: sessionId,
    );

    final serverInfo = await _embeddedServer!.start(port: port);

    // Forward join requests
    _embeddedServer!.joinRequests.listen((request) {
      _joinRequestController.add(request);
    });

    _updateRemoteAccessState(
      isEnabled: true,
      serverInfo: serverInfo,
      clients: _embeddedServer!.clients,
    );

    return serverInfo;
  }

  /// Disable remote access.
  ///
  /// Stops the embedded server and disconnects all remote clients.
  Future<void> disableRemoteAccess() async {
    if (_embeddedServer == null) return;

    await _embeddedServer!.stop();
    _embeddedServer = null;

    _updateRemoteAccessState(
      isEnabled: false,
      serverInfo: null,
      clients: [],
    );
  }

  /// Respond to a join request from a remote client.
  Future<void> respondToJoinRequest(
    String requestId,
    JoinResponse response,
  ) async {
    if (_embeddedServer == null) return;

    await _embeddedServer!.respondToJoinRequest(requestId, response);

    // Update client list
    _updateRemoteAccessState(clients: _embeddedServer!.clients);
  }

  /// Connect to a remote vide server.
  ///
  /// This switches to remote mode and connects via WebSocket.
  Future<void> connectToRemote(Uri serverUri, String sessionId) async {
    if (_mode == SessionMode.remote) {
      throw StateError('Already connected to a remote server');
    }

    // Disable any local remote access first
    await disableRemoteAccess();

    _mode = SessionMode.remote;

    // Note: The actual WebSocket connection is handled by vide_client
    // The TUI would use WebSocketSessionTransport directly
  }

  /// Disconnect from remote server and switch back to local mode.
  Future<void> disconnectFromRemote() async {
    if (_mode != SessionMode.remote) return;

    _mode = SessionMode.local;
  }

  void _updateRemoteAccessState({
    bool? isEnabled,
    ServerInfo? serverInfo,
    List<ConnectedClient>? clients,
  }) {
    _remoteAccessState = _remoteAccessState.copyWith(
      isEnabled: isEnabled,
      serverInfo: serverInfo,
      clients: clients,
    );
    _remoteAccessController.add(_remoteAccessState);
  }

  /// Get the current connected clients (only when remote access is enabled).
  List<ConnectedClient> get connectedClients {
    return _embeddedServer?.clients ?? [];
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await disableRemoteAccess();
    await _remoteAccessController.close();
    await _joinRequestController.close();
  }
}

/// Provider for the session service.
final sessionServiceProvider = Provider<SessionService>((ref) {
  final container = ref.read(providerContainerProvider);
  final service = SessionService(container: container);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider to access the ProviderContainer (for SessionService).
/// This must be overridden at app startup.
final providerContainerProvider = Provider<ProviderContainer>((ref) {
  throw UnimplementedError(
    'providerContainerProvider must be overridden at app startup',
  );
});
