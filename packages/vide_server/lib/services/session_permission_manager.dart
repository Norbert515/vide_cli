import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'server_config.dart';

final _log = Logger('SessionPermissionManager');

/// Callback to send a permission request event to the client
typedef PermissionRequestCallback =
    void Function(
      String requestId,
      String toolName,
      Map<String, dynamic> toolInput,
      String? inferredPattern,
      String agentId,
      String agentType,
      String? agentName,
      String? taskName,
    );

/// Callback to send a permission timeout event to the client
typedef PermissionTimeoutCallback =
    void Function(
      String requestId,
      String toolName,
      int timeoutSeconds,
      String agentId,
      String agentType,
      String? agentName,
      String? taskName,
    );

/// Result of a permission request
sealed class SessionPermissionResult {
  const SessionPermissionResult();
}

class SessionPermissionAllow extends SessionPermissionResult {
  const SessionPermissionAllow();
}

class SessionPermissionDeny extends SessionPermissionResult {
  final String message;
  const SessionPermissionDeny(this.message);
}

/// Pending permission request waiting for response
class _PendingPermission {
  final String requestId;
  final String sessionId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String agentId;
  final String agentType;
  final String? agentName;
  final String? taskName;
  final Completer<SessionPermissionResult> completer;
  final Timer timeoutTimer;

  _PendingPermission({
    required this.requestId,
    required this.sessionId,
    required this.toolName,
    required this.toolInput,
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    required this.completer,
    required this.timeoutTimer,
  });

  void cancel() {
    timeoutTimer.cancel();
    if (!completer.isCompleted) {
      completer.complete(const SessionPermissionDeny('Request cancelled'));
    }
  }
}

/// Registered session that can receive permission requests
class _RegisteredSession {
  final String sessionId;
  final PermissionRequestCallback onPermissionRequest;
  final PermissionTimeoutCallback onPermissionTimeout;

  _RegisteredSession({
    required this.sessionId,
    required this.onPermissionRequest,
    required this.onPermissionTimeout,
  });
}

/// Global manager for interactive permission requests across sessions.
///
/// This bridges the gap between:
/// - Permission callbacks (created at agent creation time)
/// - WebSocket sessions (connected later)
///
/// Flow:
/// 1. Session registers when WebSocket connects
/// 2. Permission callback creates a pending request
/// 3. Manager sends event to the registered session
/// 4. Session forwards response back to manager
/// 5. Manager completes the pending request
class SessionPermissionManager {
  static final instance = SessionPermissionManager._();

  SessionPermissionManager._();

  /// Maximum time to wait for a session to be registered before denying.
  /// This handles the race condition where Claude tries to use a tool
  /// before the WebSocket connects.
  static const _sessionRegistrationTimeout = Duration(seconds: 10);

  /// Server config (loaded once at startup)
  ServerConfig _config = ServerConfig.defaultConfig;

  /// Registered sessions by session ID
  final Map<String, _RegisteredSession> _sessions = {};

  /// Pending permission requests by request ID
  final Map<String, _PendingPermission> _pendingRequests = {};

  /// Completers waiting for session registration, keyed by session ID
  final Map<String, List<Completer<_RegisteredSession?>>> _sessionWaiters = {};

  /// Initialize with server config
  void initialize(ServerConfig config) {
    _config = config;
  }

  /// Register a session to receive permission requests
  void registerSession({
    required String sessionId,
    required PermissionRequestCallback onPermissionRequest,
    required PermissionTimeoutCallback onPermissionTimeout,
  }) {
    final session = _RegisteredSession(
      sessionId: sessionId,
      onPermissionRequest: onPermissionRequest,
      onPermissionTimeout: onPermissionTimeout,
    );
    _sessions[sessionId] = session;

    // Complete any waiters for this session
    final waiters = _sessionWaiters.remove(sessionId);
    if (waiters != null) {
      for (final waiter in waiters) {
        if (!waiter.isCompleted) {
          waiter.complete(session);
        }
      }
    }

    _log.info('Session registered: $sessionId');
  }

  /// Unregister a session (e.g., when WebSocket disconnects)
  void unregisterSession(String sessionId) {
    _sessions.remove(sessionId);

    // Cancel any pending requests for this session
    final pendingForSession = _pendingRequests.values
        .where((p) => p.sessionId == sessionId)
        .toList();
    for (final pending in pendingForSession) {
      pending.cancel();
      _pendingRequests.remove(pending.requestId);
    }

    _log.info('Session unregistered: $sessionId');
  }

  /// Request permission from the user.
  ///
  /// Returns the result after user responds or timeout.
  /// If no session is registered after waiting, denies.
  Future<SessionPermissionResult> requestPermission({
    required String sessionId,
    required String toolName,
    required Map<String, dynamic> toolInput,
    String? inferredPattern,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
  }) async {
    // If auto-approve is enabled, just allow
    if (_config.autoApproveAll) {
      _log.info('Auto-approving $toolName (auto-approve-all enabled)');
      return const SessionPermissionAllow();
    }

    // Wait for session to be registered (handles race condition where
    // Claude tries to use a tool before WebSocket connects)
    _RegisteredSession? session = _sessions[sessionId];
    if (session == null) {
      _log.fine('Session $sessionId not registered yet, waiting...');
      session = await _waitForSession(sessionId);
    }

    if (session == null) {
      _log.warning(
        'No session registered for $sessionId after waiting, denying $toolName',
      );
      return const SessionPermissionDeny(
        'No active client connection to request permission',
      );
    }

    // Create request ID and completer
    final requestId = const Uuid().v4();
    final completer = Completer<SessionPermissionResult>();

    // Set up timeout
    final timeoutTimer = Timer(_config.permissionTimeout, () {
      _handleTimeout(requestId);
    });

    // Store pending request
    final pending = _PendingPermission(
      requestId: requestId,
      sessionId: sessionId,
      toolName: toolName,
      toolInput: toolInput,
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      completer: completer,
      timeoutTimer: timeoutTimer,
    );
    _pendingRequests[requestId] = pending;

    // Send permission request event to client
    session.onPermissionRequest(
      requestId,
      toolName,
      toolInput,
      inferredPattern,
      agentId,
      agentType,
      agentName,
      taskName,
    );

    _log.info('Permission request sent: $requestId for $toolName');

    // Wait for response
    return completer.future;
  }

  /// Handle incoming permission response from client
  bool handlePermissionResponse({
    required String requestId,
    required bool allow,
    String? message,
  }) {
    final pending = _pendingRequests.remove(requestId);
    if (pending == null) {
      _log.warning('No pending request for ID: $requestId');
      return false;
    }

    pending.timeoutTimer.cancel();

    if (pending.completer.isCompleted) {
      _log.warning('Request already completed: $requestId');
      return false;
    }

    _log.info('Permission response: $requestId -> ${allow ? "allow" : "deny"}');

    if (allow) {
      pending.completer.complete(const SessionPermissionAllow());
    } else {
      pending.completer.complete(
        SessionPermissionDeny(message ?? 'User denied permission'),
      );
    }

    return true;
  }

  void _handleTimeout(String requestId) {
    final pending = _pendingRequests.remove(requestId);
    if (pending == null || pending.completer.isCompleted) {
      return;
    }

    _log.warning('Permission request timed out: $requestId');

    // Notify session of timeout
    final session = _sessions[pending.sessionId];
    session?.onPermissionTimeout(
      requestId,
      pending.toolName,
      _config.permissionTimeoutSeconds,
      pending.agentId,
      pending.agentType,
      pending.agentName,
      pending.taskName,
    );

    // Complete with deny
    pending.completer.complete(
      SessionPermissionDeny(
        'Permission request timed out after ${_config.permissionTimeoutSeconds} seconds',
      ),
    );
  }

  /// Wait for a session to be registered, with timeout.
  ///
  /// Returns the session if registered within timeout, null otherwise.
  Future<_RegisteredSession?> _waitForSession(String sessionId) async {
    final completer = Completer<_RegisteredSession?>();

    // Add to waiters list
    _sessionWaiters.putIfAbsent(sessionId, () => []).add(completer);

    // Set up timeout
    final timer = Timer(_sessionRegistrationTimeout, () {
      if (!completer.isCompleted) {
        // Remove from waiters and complete with null
        _sessionWaiters[sessionId]?.remove(completer);
        completer.complete(null);
      }
    });

    try {
      final session = await completer.future;
      if (session != null) {
        _log.fine('Session $sessionId registered');
      }
      return session;
    } finally {
      timer.cancel();
    }
  }

  /// Number of pending requests (for testing)
  int get pendingCount => _pendingRequests.length;

  /// Number of registered sessions (for testing)
  int get sessionCount => _sessions.length;
}
