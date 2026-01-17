/// Providers for VideSession and ConversationStateManager.
///
/// These providers bridge the public vide_core API with the TUI state management.
library;

import 'dart:async';

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/api.dart' as api;
import 'package:vide_core/vide_core.dart';

/// Provider for the VideCore instance.
///
/// This is created from the existing ProviderContainer using [api.VideCore.fromContainer].
final videoCoreProvider = Provider<api.VideCore>((ref) {
  throw UnimplementedError('videoCoreProvider must be overridden in main.dart');
});

/// Provider for the current VideSession based on the active network.
///
/// Returns null if no network is currently active.
final currentVideSessionProvider = Provider<api.VideSession?>((ref) {
  final core = ref.watch(videoCoreProvider);
  final networkState = ref.watch(agentNetworkManagerProvider);
  final currentNetwork = networkState.currentNetwork;

  if (currentNetwork == null) return null;

  return core.getSessionForNetwork(currentNetwork.id);
});

/// Provider for ConversationStateManager tied to the current session.
///
/// This manages state accumulation from VideSession events.
/// Returns null if no session is active.
final conversationStateManagerProvider =
    Provider<api.ConversationStateManager?>((ref) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null) return null;

  // Get or create state manager for this session
  return ref.watch(_sessionStateManagerProvider(session.id));
});

/// Internal: Creates and manages a ConversationStateManager per session.
final _sessionStateManagerProvider =
    Provider.family<api.ConversationStateManager, String>((ref, sessionId) {
  final session = ref.watch(currentVideSessionProvider);
  if (session == null || session.id != sessionId) {
    // Session changed or doesn't match - return empty manager
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
/// ```
final agentConversationStateProvider =
    Provider.family<api.AgentConversationState?, String>((ref, agentId) {
  final manager = ref.watch(conversationStateManagerProvider);
  if (manager == null) return null;

  return manager.getAgentState(agentId);
});

/// Provider that triggers rebuilds when conversation state changes.
///
/// This uses a stream to notify when the ConversationStateManager has updates.
/// Widgets can watch this to rebuild when any agent's state changes.
final conversationStateChangedProvider = StreamProvider<void>((ref) {
  final manager = ref.watch(conversationStateManagerProvider);
  if (manager == null) return const Stream.empty();

  return manager.onStateChanged;
});
