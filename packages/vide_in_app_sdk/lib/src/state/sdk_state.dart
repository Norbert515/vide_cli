import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vide_client/vide_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection state for the SDK.
enum VideSdkConnectionState { disconnected, connecting, connected, error }

const _kHostKey = 'vide_sdk_host';
const _kPortKey = 'vide_sdk_port';
const _kWorkingDirKey = 'vide_sdk_working_directory';

/// Central state for the Vide in-app SDK.
///
/// Manages the lifecycle of the [VideClient] and [RemoteVideSession],
/// exposes connection state, and provides the active session to the UI.
class VideSdkState extends ChangeNotifier {
  String? _host;
  int? _port;
  String? _workingDirectory;

  VideClient? _client;
  RemoteVideSession? _session;
  VideSdkConnectionState _connectionState = VideSdkConnectionState.disconnected;
  String? _errorMessage;
  StreamSubscription<VideEvent>? _eventSubscription;

  VideSdkState({String? host, int? port, String? workingDirectory})
    : _host = host,
      _port = port,
      _workingDirectory = workingDirectory;

  String? get host => _host;
  int? get port => _port;
  String? get workingDirectory => _workingDirectory;
  bool get isConfigured =>
      _host != null &&
      _host!.isNotEmpty &&
      _port != null &&
      _workingDirectory != null &&
      _workingDirectory!.isNotEmpty;

  VideSdkConnectionState get connectionState => _connectionState;
  String? get errorMessage => _errorMessage;
  RemoteVideSession? get session => _session;
  VideState? get videState => _session?.state;
  bool get hasActiveSession =>
      _session != null && _connectionState == VideSdkConnectionState.connected;

  /// Load persisted configuration from shared preferences.
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _host ??= prefs.getString(_kHostKey);
    _port ??= prefs.getInt(_kPortKey);
    _workingDirectory ??= prefs.getString(_kWorkingDirKey);
    notifyListeners();
  }

  /// Update and persist configuration.
  Future<void> updateConfig({
    required String host,
    required int port,
    required String workingDirectory,
  }) async {
    _host = host;
    _port = port;
    _workingDirectory = workingDirectory;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHostKey, host);
    await prefs.setInt(_kPortKey, port);
    await prefs.setString(_kWorkingDirKey, workingDirectory);

    // Disconnect any existing session since config changed
    await disconnect();
    notifyListeners();
  }

  /// Test connection to a server by checking its health endpoint.
  ///
  /// Returns true if the server is reachable and healthy.
  Future<bool> testConnection({required String host, required int port}) async {
    final client = VideClient(host: host, port: port);
    return client.checkHealth();
  }

  /// Connect to the server and create a new session with the given message.
  Future<void> createSession(
    String initialMessage, {
    List<VideAttachment>? attachments,
  }) async {
    _connectionState = VideSdkConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    _client = VideClient(host: _host!, port: _port!);

    final pending = createPendingRemoteVideSession(
      initialMessage: initialMessage,
      attachments: attachments,
    );
    _session = pending.session as RemoteVideSession;
    notifyListeners();

    try {
      final sessionInfo = await _client!.createSessionRaw(
        initialMessage: initialMessage,
        workingDirectory: _workingDirectory!,
      );

      pending.completeWithConnection(
        sessionId: sessionInfo.sessionId,
        channel: WebSocketChannel.connect(Uri.parse(sessionInfo.wsUrl)),
      );
      _connectionState = VideSdkConnectionState.connected;
      _setupEventListening();
      notifyListeners();
    } catch (e) {
      pending.fail(e.toString());
      _connectionState = VideSdkConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Connect to an existing session by ID.
  Future<void> connectToSession(String sessionId) async {
    _connectionState = VideSdkConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    _client = VideClient(host: _host!, port: _port!);

    try {
      _session = await _client!.connectToSession(sessionId);
      _connectionState = VideSdkConnectionState.connected;
      _setupEventListening();
      notifyListeners();
    } catch (e) {
      _connectionState = VideSdkConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _setupEventListening() {
    _eventSubscription?.cancel();
    _eventSubscription = _session?.events.listen((_) {
      notifyListeners();
    });

    _session?.stateStream.listen((_) {
      notifyListeners();
    });
  }

  /// Send a message to the main agent.
  void sendMessage(String text, {List<VideAttachment>? attachments}) {
    _session?.sendMessage(VideMessage(text: text, attachments: attachments));
    notifyListeners();
  }

  /// Respond to a permission request.
  void respondToPermission(String requestId, {required bool allow}) {
    _session?.respondToPermission(requestId, allow: allow);
  }

  /// Respond to a plan approval request.
  void respondToPlanApproval(
    String requestId, {
    required String action,
    String? feedback,
  }) {
    _session?.respondToPlanApproval(
      requestId,
      action: action,
      feedback: feedback,
    );
  }

  /// Abort the current session.
  Future<void> abort() async {
    await _session?.abort();
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _session?.dispose();
    _session = null;
    _client = null;
    _connectionState = VideSdkConnectionState.disconnected;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _session?.dispose();
    super.dispose();
  }
}
