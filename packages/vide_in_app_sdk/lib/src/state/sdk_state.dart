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
  PlanApprovalRequestEvent? _pendingPlanApproval;
  AskUserQuestionEvent? _pendingAskUserQuestion;
  final List<PermissionRequestEvent> _pendingPermissions = [];

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

  /// A [VideClient] for API calls (filesystem, git, etc.).
  ///
  /// Available whenever host and port are configured, regardless of session
  /// state.
  VideClient? get client =>
      _host != null && _port != null ? VideClient(host: _host!, port: _port!) : null;
  RemoteVideSession? get session => _session;
  VideState? get videState => _session?.state;
  bool get hasActiveSession =>
      _session != null && _connectionState == VideSdkConnectionState.connected;

  PlanApprovalRequestEvent? get pendingPlanApproval => _pendingPlanApproval;
  AskUserQuestionEvent? get pendingAskUserQuestion => _pendingAskUserQuestion;
  PermissionRequestEvent? get currentPermission => _pendingPermissions.firstOrNull;

  void clearPendingPlanApproval() {
    _pendingPlanApproval = null;
    notifyListeners();
  }

  void clearPendingAskUserQuestion() {
    _pendingAskUserQuestion = null;
    notifyListeners();
  }

  void dequeuePermission() {
    if (_pendingPermissions.isNotEmpty) {
      _pendingPermissions.removeAt(0);
      notifyListeners();
    }
  }

  void _removePermissionByRequestId(String requestId) {
    _pendingPermissions.removeWhere((r) => r.requestId == requestId);
    notifyListeners();
  }

  /// Whether the server health check has passed (server is reachable).
  /// null = not checked yet, true = reachable, false = unreachable.
  bool? _serverReachable;
  bool? get serverReachable => _serverReachable;

  /// Sessions from the server filtered to the configured working directory.
  List<SessionSummary> _sessions = [];
  List<SessionSummary> get sessions => _sessions;
  bool _sessionsFetched = false;
  bool get sessionsFetched => _sessionsFetched;

  /// Load persisted configuration from shared preferences.
  ///
  /// Also kicks off a background health check if configured.
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _host ??= prefs.getString(_kHostKey);
    _port ??= prefs.getInt(_kPortKey);
    _workingDirectory ??= prefs.getString(_kWorkingDirKey);
    notifyListeners();

    if (isConfigured) {
      unawaited(checkServerHealth());
    }
  }

  /// Check if the configured server is reachable.
  ///
  /// If reachable, also fetches the session list for the working directory.
  Future<void> checkServerHealth() async {
    if (_host == null || _port == null) return;

    _serverReachable = null;
    notifyListeners();

    final reachable = await testConnection(host: _host!, port: _port!);
    _serverReachable = reachable;
    notifyListeners();

    if (reachable) {
      unawaited(fetchSessions());
    }
  }

  /// Fetch sessions from the server filtered to the configured working directory.
  Future<void> fetchSessions() async {
    if (_host == null || _port == null || _workingDirectory == null) return;

    final client = VideClient(host: _host!, port: _port!);
    try {
      final all = await client.listSessions();
      _sessions = all
          .where((s) =>
              s.workingDirectory == _workingDirectory &&
              s.state == 'ready')
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _sessionsFetched = true;
      notifyListeners();
    } catch (_) {
      // Non-critical — leave list empty
    }
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
    _serverReachable = null;
    notifyListeners();

    unawaited(checkServerHealth());
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
    _eventSubscription = _session?.events.listen((event) {
      switch (event) {
        case PermissionRequestEvent():
          _pendingPermissions.add(event);
        case PermissionResolvedEvent(:final requestId):
          _removePermissionByRequestId(requestId);
          return; // already notified in helper
        case PlanApprovalRequestEvent():
          _pendingPlanApproval = event;
        case PlanApprovalResolvedEvent(:final requestId):
          if (_pendingPlanApproval?.requestId == requestId) {
            _pendingPlanApproval = null;
          }
        case AskUserQuestionEvent():
          _pendingAskUserQuestion = event;
        case AskUserQuestionResolvedEvent(:final requestId):
          if (_pendingAskUserQuestion?.requestId == requestId) {
            _pendingAskUserQuestion = null;
          }
        default:
          break;
      }
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
  void respondToPermission(
    String requestId, {
    required bool allow,
    bool remember = false,
  }) {
    _session?.respondToPermission(requestId, allow: allow, remember: remember);
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

  /// Respond to an AskUserQuestion request.
  void respondToAskUserQuestion(
    String requestId, {
    required Map<String, String> answers,
  }) {
    _session?.respondToAskUserQuestion(requestId, answers: answers);
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
    _pendingPlanApproval = null;
    _pendingAskUserQuestion = null;
    _pendingPermissions.clear();
    notifyListeners();

    // Refresh session list so the disconnected session appears under "Recent".
    unawaited(fetchSessions());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _session?.dispose();
    super.dispose();
  }
}
