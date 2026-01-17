/// Provider for managing conversation state from VideSession events.
///
/// This bridges the VideSession event stream to the ConversationStateManager,
/// providing accumulated conversation state for UI rendering.
library;

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/api.dart' as api;
import 'package:vide_cli/main.dart';

/// Provider for the ConversationStateManager tied to the current session.
///
/// This listens to the current VideSession's events and accumulates them
/// into renderable conversation state.
///
/// Usage:
/// ```dart
/// final stateManager = context.watch(sessionConversationStateProvider);
/// final agentState = stateManager?.getAgentState(agentId);
/// ```
final sessionConversationStateProvider =
    Provider<api.ConversationStateManager?>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return null;

  // Get or create the state manager for this session
  final manager = ref.watch(_sessionStateManagerProvider(session.id));
  return manager;
});

/// Internal family provider that creates a ConversationStateManager per session.
///
/// This ensures we create one manager per session and properly dispose it.
final _sessionStateManagerProvider =
    Provider.family<api.ConversationStateManager, String>((ref, sessionId) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null || session.id != sessionId) {
    // Return an empty manager if session doesn't match
    return api.ConversationStateManager();
  }

  final manager = api.ConversationStateManager();

  // Subscribe to session events
  final subscription = session.events.listen((event) {
    manager.handleEvent(event);
  });

  // Clean up on dispose
  ref.onDispose(() {
    subscription.cancel();
    manager.dispose();
  });

  return manager;
});

/// Provider for a specific agent's conversation state.
///
/// Usage:
/// ```dart
/// final agentState = context.watch(agentConversationStateProvider(agentId));
/// if (agentState != null) {
///   for (final message in agentState.messages) {
///     // Render message using VideMessageAdapter
///   }
/// }
/// ```
final agentConversationStateProvider =
    Provider.family<api.AgentConversationState?, String>((ref, agentId) {
  final manager = ref.watch(sessionConversationStateProvider);
  if (manager == null) return null;

  // Watch for changes in the manager
  // Note: This won't trigger rebuilds on every event since we're not
  // watching the stream directly. For reactive updates, the consuming
  // widget should listen to manager.onStateChanged.
  return manager.getAgentState(agentId);
});
