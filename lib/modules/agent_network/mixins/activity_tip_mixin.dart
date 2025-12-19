import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';
import 'package:vide_cli/modules/haiku/fact_source_service.dart';
import 'package:vide_cli/modules/agent_network/models/agent_status.dart';
import 'package:vide_cli/modules/agent_network/state/agent_status_manager.dart';

/// Mixin that provides activity tip functionality.
///
/// Shows "did you know" facts after 4 seconds of agent activity.
/// Facts display for a minimum of 8 seconds to prevent flickering.
///
/// Usage:
/// 1. Add `with ActivityTipMixin` to your State class
/// 2. Implement `activityTipConversation` and `activityTipAgentId` getters
/// 3. Call `initActivityTips()` in initState
/// 4. Call `disposeActivityTips()` in dispose
/// 5. Call start/stop at conversation state change points
/// 6. Call `handleAgentStatusChange()` from build when agent status changes
mixin ActivityTipMixin<T extends StatefulComponent> on State<T> {
  // State
  Timer? _activityTipTimer;
  static const _activityTipThreshold = Duration(seconds: 4);
  bool _isGeneratingActivityTip = false;

  // Minimum fact display duration tracking
  DateTime? _factShownAt;
  Timer? _factDisplayTimer;
  static const _minimumFactDisplayDuration = Duration(seconds: 8);

  /// Override this to provide the current conversation state
  Conversation get activityTipConversation;

  /// Override this to provide the agent session ID for status lookups
  String get activityTipAgentId;

  /// Call in initState if already receiving response
  void initActivityTips() {
    if (activityTipConversation.state == ConversationState.receivingResponse) {
      startActivityTipTimer();
    }
  }

  /// Call in dispose to clean up both timers
  void disposeActivityTips() {
    _activityTipTimer?.cancel();
    _factDisplayTimer?.cancel();
  }

  void startActivityTipTimer() {
    _stopActivityTipTimerInternal();
    _activityTipTimer = Timer(_activityTipThreshold, _onActivityTipThresholdReached);
  }

  void stopActivityTipTimer() {
    _stopActivityTipTimerInternal();
    _clearActivityTipWithMinimumDuration();
  }

  void _stopActivityTipTimerInternal() {
    _activityTipTimer?.cancel();
    _activityTipTimer = null;
    _isGeneratingActivityTip = false;
  }

  /// Check if we should show activity tips.
  /// Tips show when: agent is receiving response OR waiting for subagents.
  bool shouldShowActivityTips() {
    final isReceiving = activityTipConversation.state == ConversationState.receivingResponse;
    final agentStatus = context.read(agentStatusProvider(activityTipAgentId));
    final isWaitingForAgent = agentStatus == AgentStatus.waitingForAgent;
    return isReceiving || isWaitingForAgent;
  }

  void _onActivityTipThresholdReached() {
    if (!mounted || _isGeneratingActivityTip) return;

    final shouldShow = shouldShowActivityTips();
    if (!shouldShow) return;

    _isGeneratingActivityTip = true;

    // Get a random pre-generated fact directly (no Haiku needed)
    final fact = FactSourceService.instance.getRandomFact();

    _isGeneratingActivityTip = false;
    if (!mounted) return;

    final shouldShowNow = shouldShowActivityTips();

    if (fact != null && shouldShowNow) {
      context.read(activityTipProvider.notifier).state = fact;
      // Record when fact was shown and start timer to clear after minimum duration
      _factShownAt = DateTime.now();
      _factDisplayTimer?.cancel();
      _factDisplayTimer = Timer(_minimumFactDisplayDuration, _onFactDisplayTimerExpired);
    }
  }

  /// Called when the minimum fact display duration has elapsed.
  /// Clears the fact if conditions no longer warrant showing it.
  void _onFactDisplayTimerExpired() {
    _factDisplayTimer = null;
    _factShownAt = null;
    if (!mounted) return;
    // Only clear if we're no longer in a state that should show tips
    if (!shouldShowActivityTips()) {
      context.read(activityTipProvider.notifier).state = null;
    }
  }

  /// Clear activity tip, respecting minimum display duration
  void _clearActivityTipWithMinimumDuration() {
    if (_factShownAt != null) {
      final elapsed = DateTime.now().difference(_factShownAt!);
      if (elapsed >= _minimumFactDisplayDuration) {
        // Minimum time elapsed, safe to clear immediately
        _factDisplayTimer?.cancel();
        _factDisplayTimer = null;
        _factShownAt = null;
        context.read(activityTipProvider.notifier).state = null;
      }
      // else: let _factDisplayTimer handle cleanup after minimum duration
    } else {
      // No fact showing, just clear
      context.read(activityTipProvider.notifier).state = null;
    }
  }

  /// Handle agent status changes from build().
  /// Call this when agentStatus changes to start/stop timer accordingly.
  /// [agentStatus] The current agent status
  /// [conversationState] The current conversation state
  void handleAgentStatusChange(AgentStatus agentStatus, ConversationState conversationState) {
    // Start timer when waiting for agent (if not already running)
    if (agentStatus == AgentStatus.waitingForAgent &&
        _activityTipTimer == null &&
        !_isGeneratingActivityTip) {
      Future.microtask(() {
        if (mounted) startActivityTipTimer();
      });
    }
    // Stop timer when no longer waiting for agent and not receiving response
    else if (agentStatus != AgentStatus.waitingForAgent &&
        conversationState != ConversationState.receivingResponse &&
        _activityTipTimer != null) {
      Future.microtask(() {
        if (mounted) {
          _stopActivityTipTimerInternal();
          _clearActivityTipWithMinimumDuration();
        }
      });
    }
  }
}
