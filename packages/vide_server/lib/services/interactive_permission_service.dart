import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:vide_core/vide_core.dart';

import '../dto/session_dto.dart';
import 'server_config.dart';

final _log = Logger('InteractivePermissionService');

/// Pending permission request waiting for client response
class _PendingRequest {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String agentId;
  final String agentType;
  final String? agentName;
  final String? taskName;
  final Completer<PermissionResult> completer;
  final DateTime createdAt;

  _PendingRequest({
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    required this.agentId,
    required this.agentType,
    this.agentName,
    this.taskName,
    required this.completer,
  }) : createdAt = DateTime.now();
}

/// Interactive permission service for REST API sessions.
///
/// Unlike the non-interactive REST permission service, this one:
/// - Returns PermissionAskUser results to the client via WebSocket
/// - Waits for client response with configurable timeout
/// - Times out to deny if client doesn't respond
///
/// Each session should have its own instance to track pending requests.
class InteractivePermissionService {
  final ServerConfig config;
  final PermissionChecker _checker;
  final SequenceGenerator _seqGen;

  /// Callback to send events to the WebSocket
  final void Function(String jsonEvent) _sendEvent;

  /// Pending permission requests waiting for client response
  final Map<String, _PendingRequest> _pendingRequests = {};

  /// Timers for request timeouts
  final Map<String, Timer> _timeoutTimers = {};

  InteractivePermissionService({
    required this.config,
    required SequenceGenerator seqGen,
    required void Function(String jsonEvent) sendEvent,
  }) : _checker = PermissionChecker(),
       _seqGen = seqGen,
       _sendEvent = sendEvent;

  /// Create a CanUseToolCallback for a specific agent.
  ///
  /// The callback integrates with PermissionChecker and handles:
  /// - Auto-approve for safe operations
  /// - Auto-deny for dangerous operations
  /// - WebSocket permission request/response for operations needing user approval
  CanUseToolCallback createCallback({
    required String agentId,
    required String agentType,
    required String cwd,
    String? agentName,
    String? taskName,
  }) {
    return (
      String toolName,
      Map<String, dynamic> rawInput,
      ToolPermissionContext context,
    ) async {
      // Convert raw map to type-safe ToolInput
      final input = ToolInput.fromJson(toolName, rawInput);

      final result = await _checker.checkPermission(
        toolName: toolName,
        input: input,
        cwd: cwd,
      );

      return switch (result) {
        PermissionAllow() => const PermissionResultAllow(),
        PermissionDeny(:final reason) => PermissionResultDeny(message: reason),
        PermissionAskUser(:final inferredPattern) => await _handleAskUser(
          toolName: toolName,
          toolInput: rawInput,
          inferredPattern: inferredPattern,
          agentId: agentId,
          agentType: agentType,
          agentName: agentName,
          taskName: taskName,
        ),
      };
    };
  }

  /// Handle PermissionAskUser by sending request to client and waiting for response.
  Future<PermissionResult> _handleAskUser({
    required String toolName,
    required Map<String, dynamic> toolInput,
    String? inferredPattern,
    required String agentId,
    required String agentType,
    String? agentName,
    String? taskName,
  }) async {
    // If auto-approve is enabled, just allow
    if (config.autoApproveAll) {
      _log.info('Auto-approving $toolName (auto-approve-all enabled)');
      return const PermissionResultAllow();
    }

    final requestId = const Uuid().v4();
    final completer = Completer<PermissionResult>();

    // Create pending request
    final pending = _PendingRequest(
      requestId: requestId,
      toolName: toolName,
      toolInput: toolInput,
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      completer: completer,
    );
    _pendingRequests[requestId] = pending;

    // Set up timeout
    _timeoutTimers[requestId] = Timer(config.permissionTimeout, () {
      _handleTimeout(requestId);
    });

    // Send permission-request event
    final event = SessionEvent.permissionRequest(
      seq: _seqGen.next(),
      agentId: agentId,
      agentType: agentType,
      agentName: agentName,
      taskName: taskName,
      requestId: requestId,
      tool: {
        'name': toolName,
        'input': toolInput,
        if (inferredPattern != null)
          'permission-suggestions': [inferredPattern],
      },
    );
    _sendEvent(event.toJsonString());

    _log.info('Permission request sent: $requestId for $toolName');

    // Wait for response (will be completed by handlePermissionResponse or timeout)
    return completer.future;
  }

  /// Handle timeout for a pending permission request.
  void _handleTimeout(String requestId) {
    final pending = _pendingRequests.remove(requestId);
    _timeoutTimers.remove(requestId)?.cancel();

    if (pending == null || pending.completer.isCompleted) {
      return;
    }

    _log.warning(
      'Permission request timed out: $requestId for ${pending.toolName}',
    );

    // Send permission-timeout event
    final event = SessionEvent.permissionTimeout(
      seq: _seqGen.next(),
      agentId: pending.agentId,
      agentType: pending.agentType,
      agentName: pending.agentName,
      taskName: pending.taskName,
      requestId: requestId,
    );
    _sendEvent(event.toJsonString());

    // Complete with deny
    pending.completer.complete(
      PermissionResultDeny(
        message:
            'Permission request timed out after ${config.permissionTimeoutSeconds} seconds',
      ),
    );
  }

  /// Handle incoming permission-response from client.
  ///
  /// Returns true if the response was handled, false if no pending request found.
  bool handlePermissionResponse(PermissionResponse response) {
    final pending = _pendingRequests.remove(response.requestId);
    _timeoutTimers.remove(response.requestId)?.cancel();

    if (pending == null) {
      _log.warning(
        'Received permission response for unknown request: ${response.requestId}',
      );
      return false;
    }

    if (pending.completer.isCompleted) {
      _log.warning(
        'Received permission response for already-completed request: ${response.requestId}',
      );
      return false;
    }

    _log.info(
      'Permission response received: ${response.requestId} -> ${response.allow ? "allow" : "deny"}',
    );

    if (response.allow) {
      pending.completer.complete(const PermissionResultAllow());
    } else {
      pending.completer.complete(
        PermissionResultDeny(
          message: response.message ?? 'User denied permission',
        ),
      );
    }

    return true;
  }

  /// Cancel all pending requests (e.g., when session ends).
  void cancelAll() {
    for (final requestId in _pendingRequests.keys.toList()) {
      final pending = _pendingRequests.remove(requestId);
      _timeoutTimers.remove(requestId)?.cancel();

      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(
          const PermissionResultDeny(message: 'Session ended'),
        );
      }
    }
  }

  /// Number of pending permission requests.
  int get pendingCount => _pendingRequests.length;
}
