import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import 'package:vide_interface/vide_interface.dart';

import '../api/vide_session.dart';
import '../models/agent_id.dart';
import '../vide_core_config.dart';

/// Handler that manages permission callbacks with late session binding.
///
/// This solves the chicken-egg problem where permission callbacks are needed
/// before the session exists. The handler is created first, then the session
/// is registered after creation via [setSession].
///
/// Example:
/// ```dart
/// final handler = PermissionHandler();
/// // ... create network with ClaudeClient using handler.createCallback()
/// final session = VideSession.create(...);
/// handler.setSession(session);  // Register this session's agents
/// ```
class PermissionHandler {
  /// Active sessions by session ID.
  final Map<String, VideSession> _sessionsById = {};

  /// Session owner by agent ID.
  final Map<String, String> _sessionIdByAgentId = {};

  /// Tracked agents for each session.
  final Map<String, Set<String>> _agentIdsBySessionId = {};

  /// Event subscriptions per session for spawn/terminate tracking.
  final Map<String, StreamSubscription<VideEvent>> _sessionSubscriptions = {};

  /// Register a session for permission handling.
  ///
  /// Must be called after the session is created, before permission
  /// callbacks for that session are invoked.
  void setSession(VideSession session) {
    final sessionId = session.state.id;
    final existingSession = _sessionsById[sessionId];
    if (existingSession != null && !identical(existingSession, session)) {
      _unregisterSession(sessionId);
    }
    _sessionsById[sessionId] = session;

    final trackedAgentIds = _agentIdsBySessionId.putIfAbsent(
      sessionId,
      () => <String>{},
    );
    for (final agentId in session.state.agentIds) {
      _sessionIdByAgentId[agentId] = sessionId;
      trackedAgentIds.add(agentId);
    }

    _sessionSubscriptions.putIfAbsent(
      sessionId,
      () => session.events.listen(
        (event) {
          if (event is AgentSpawnedEvent) {
            _sessionIdByAgentId[event.agentId] = sessionId;
            trackedAgentIds.add(event.agentId);
          } else if (event is AgentTerminatedEvent) {
            if (_sessionIdByAgentId[event.agentId] == sessionId) {
              _sessionIdByAgentId.remove(event.agentId);
            }
            trackedAgentIds.remove(event.agentId);
          }
        },
        onDone: () {
          _unregisterSession(sessionId);
        },
      ),
    );
  }

  void _unregisterSession(String sessionId) {
    final subscription = _sessionSubscriptions.remove(sessionId);
    subscription?.cancel();

    _sessionsById.remove(sessionId);
    final trackedAgentIds =
        _agentIdsBySessionId.remove(sessionId) ?? <String>{};
    for (final agentId in trackedAgentIds) {
      if (_sessionIdByAgentId[agentId] == sessionId) {
        _sessionIdByAgentId.remove(agentId);
      }
    }
  }

  /// Create a permission callback that delegates to the session.
  ///
  /// The callback uses late binding - when invoked, it resolves the session by
  /// [agentId] from sessions previously registered via [setSession].
  /// If no matching session is found, auto-allows.
  CanUseToolCallback createCallback({
    required String cwd,
    required AgentId agentId,
    required String? agentName,
    required String? agentType,
    String? permissionMode,
  }) {
    final agentIdValue = agentId.toString();
    return (toolName, input, context) async {
      final sessionId = _sessionIdByAgentId[agentIdValue];
      final session = sessionId == null ? null : _sessionsById[sessionId];
      if (session == null) {
        // This should only happen if permission callback fires before the
        // session is registered with setSession().
        assert(
          false,
          'Permission requested before session was registered via setSession() '
          '(agentId: $agentIdValue)',
        );
        // Auto-allow as fallback (production safety)
        return const PermissionResultAllow();
      }

      // For LocalVideSession, use the internal claude_sdk permission callback
      // directly to avoid unnecessary conversions.
      if (session is LocalVideSession) {
        final callback = session.createClaudePermissionCallback(
          agentId: agentIdValue,
          agentName: agentName,
          agentType: agentType,
          cwd: cwd,
          permissionMode: permissionMode,
        );
        return callback(toolName, input, context);
      }

      // For other session types, use the interface method and convert result
      final callback = session.createPermissionCallback(
        agentId: agentIdValue,
        agentName: agentName,
        agentType: agentType,
        cwd: cwd,
        permissionMode: permissionMode,
      );
      final videResult = await callback(
        toolName,
        input,
        VidePermissionContext(),
      );
      return switch (videResult) {
        VidePermissionAllow(:final updatedInput) => PermissionResultAllow(
          updatedInput: updatedInput,
        ),
        VidePermissionDeny(:final message) => PermissionResultDeny(
          message: message,
        ),
      };
    };
  }
}

/// Context for creating a canUseTool callback for a specific agent.
///
/// Contains all the information needed to create an appropriate permission
/// callback, including agent identity and configuration.
class PermissionCallbackContext {
  final String cwd;
  final AgentId agentId;
  final String? agentName;
  final String? agentType;
  final String? permissionMode;

  /// The permission handler for late session binding.
  final PermissionHandler permissionHandler;

  const PermissionCallbackContext({
    required this.cwd,
    required this.agentId,
    this.agentName,
    this.agentType,
    this.permissionMode,
    required this.permissionHandler,
  });
}

/// Provider for the permission handler. Reads from [videCoreConfigProvider].
final permissionHandlerProvider = Provider<PermissionHandler>((ref) {
  return ref.watch(videCoreConfigProvider).permissionHandler;
});
