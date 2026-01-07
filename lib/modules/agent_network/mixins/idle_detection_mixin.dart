import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/modules/haiku/haiku_service.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';
import 'package:vide_cli/modules/haiku/prompts/idle_prompt.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_manager.dart';
import 'package:vide_cli/modules/agent_network/service/claude_manager.dart';

/// Mixin that provides idle detection functionality.
///
/// Detects when user has been idle for 2 minutes and generates
/// a passive-aggressive message via Haiku.
///
/// Usage:
/// 1. Add `with IdleDetectionMixin` to your State class
/// 2. Implement `idleDetectionConversation` getter
/// 3. Call `initIdleDetection()` in initState (after checking if already idle)
/// 4. Call `disposeIdleDetection()` in dispose
/// 5. Call start/stop/reset at appropriate trigger points
mixin IdleDetectionMixin<T extends StatefulComponent> on State<T> {
  // State
  Timer? _idleTimer;
  DateTime? _idleStartTime;
  static const _idleThreshold = Duration(minutes: 2);
  bool _isGeneratingIdleMessage = false;

  /// Override this to provide the current conversation state
  Conversation get idleDetectionConversation;

  /// Call in initState if conversation is already idle
  void initIdleDetection() {
    if (idleDetectionConversation.state == ConversationState.idle) {
      startIdleTimer();
    }
  }

  /// Call in dispose to clean up timer
  void disposeIdleDetection() {
    _idleTimer?.cancel();
  }

  void startIdleTimer() {
    stopIdleTimer();
    _idleStartTime = DateTime.now();
    _idleTimer = Timer(_idleThreshold, _onIdleThresholdReached);
  }

  void stopIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _idleStartTime = null;
  }

  void resetIdleTimer() {
    // Clear any existing idle message and restart the timer
    context.read(idleMessageProvider.notifier).state = null;
    if (idleDetectionConversation.state == ConversationState.idle) {
      startIdleTimer();
    }
  }

  void _onIdleThresholdReached() async {
    if (!mounted || _isGeneratingIdleMessage) return;
    if (idleDetectionConversation.state != ConversationState.idle) return;

    // Check if ANY agent in the network is currently working
    final networkState = context.read(agentNetworkManagerProvider);
    for (final agentId in networkState.agentIds) {
      final client = context.read(claudeProvider(agentId));
      if (client != null && client.currentConversation.state != ConversationState.idle) {
        // Some agent is still working, don't show idle message
        // Restart timer to check again later
        startIdleTimer();
        return;
      }
    }

    _isGeneratingIdleMessage = true;

    final idleTime = _idleStartTime != null
        ? DateTime.now().difference(_idleStartTime!)
        : _idleThreshold;

    final systemPrompt = IdlePrompt.build(idleTime);
    final result = await HaikuService.invoke(
      systemPrompt: systemPrompt,
      userMessage: 'Generate an idle message for ${idleTime.inSeconds} seconds of inactivity.',
      delay: Duration.zero,
    );

    _isGeneratingIdleMessage = false;
    if (!mounted) return;

    if (result != null) {
      context.read(idleMessageProvider.notifier).state = result;
    }
  }
}
