import 'dart:async';
import 'dart:io';

import 'package:claude_sdk/claude_sdk.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';
import '../../permissions/permission_scope.dart';
import 'package:vide_core/vide_core.dart';

/// Provides the project name from the current working directory.
final projectNameProvider = Provider<String>((ref) {
  return path.basename(Directory.current.path);
});

/// Braille spinner frames for animated title
const _brailleFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

/// Animation interval for braille spinner (slower than component spinners)
const _animationInterval = Duration(milliseconds: 250);

/// State for the animated console title
class ConsoleTitleState {
  final int frameIndex;

  const ConsoleTitleState({this.frameIndex = 0});

  ConsoleTitleState copyWith({int? frameIndex}) {
    return ConsoleTitleState(frameIndex: frameIndex ?? this.frameIndex);
  }

  String get currentFrame => _brailleFrames[frameIndex % _brailleFrames.length];
}

/// State notifier that manages the braille animation timer
class ConsoleTitleNotifier extends StateNotifier<ConsoleTitleState> {
  Timer? _animationTimer;

  ConsoleTitleNotifier() : super(const ConsoleTitleState());

  /// Start the animation timer
  void startAnimation() {
    if (_animationTimer != null) return; // Already running

    _animationTimer = Timer.periodic(_animationInterval, (_) {
      state = state.copyWith(
        frameIndex: (state.frameIndex + 1) % _brailleFrames.length,
      );
    });
  }

  /// Stop the animation timer
  void stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    // Reset to first frame when stopped
    state = const ConsoleTitleState();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }
}

/// Provider for the animation state notifier
final consoleTitleNotifierProvider =
    StateNotifierProvider<ConsoleTitleNotifier, ConsoleTitleState>((ref) {
      return ConsoleTitleNotifier();
    });

/// Aggregated status from all agents
enum _AggregatedStatus {
  needsAttention, // waitingForUser OR permission pending
  working, // working or waitingForAgent
  idle, // all idle
}

/// Infer actual status based on explicit status and conversation state.
/// This provides safeguards against agents forgetting to call setAgentStatus.
AgentStatus _inferActualStatus(
  AgentStatus explicitStatus,
  Conversation? conversation,
) {
  if (conversation == null) {
    return explicitStatus;
  }

  // If conversation is processing, agent is definitely working
  if (conversation.isProcessing) {
    return AgentStatus.working;
  }

  // If conversation is idle but agent claims to be working, override to idle
  // This handles cases where agent forgot to call setAgentStatus("idle")
  if (conversation.state == ConversationState.idle &&
      explicitStatus == AgentStatus.working) {
    return AgentStatus.idle;
  }

  return explicitStatus;
}

/// Determines the aggregated status across all agents and permission state
_AggregatedStatus _getAggregatedStatus(Ref ref) {
  final networkState = ref.watch(agentNetworkManagerProvider);
  final agentIds = networkState.agentIds;
  final permissionState = ref.watch(permissionStateProvider);
  final askUserQuestionState = ref.watch(askUserQuestionStateProvider);
  final claudeClients = ref.watch(claudeManagerProvider);

  // Check if there's a pending permission request or askUserQuestion
  if (permissionState.current != null || askUserQuestionState.current != null) {
    return _AggregatedStatus.needsAttention;
  }

  // No agents = Idle
  if (agentIds.isEmpty) {
    return _AggregatedStatus.idle;
  }

  bool hasWorking = false;

  for (final agentId in agentIds) {
    final explicitStatus = ref.watch(agentStatusProvider(agentId));

    // Get conversation state for this agent
    final client = claudeClients[agentId];
    final conversation = client?.currentConversation;

    // Infer actual status
    final status = _inferActualStatus(explicitStatus, conversation);

    switch (status) {
      case AgentStatus.waitingForUser:
        return _AggregatedStatus.needsAttention;
      case AgentStatus.working:
      case AgentStatus.waitingForAgent:
        hasWorking = true;
        break;
      case AgentStatus.idle:
        // Keep checking other agents
        break;
    }
  }

  if (hasWorking) {
    return _AggregatedStatus.working;
  }

  return _AggregatedStatus.idle;
}

/// Provides the aggregated console title based on the status of all agents in the network.
///
/// Format: "ProjectName <emoji>"
///
/// Status aggregation logic (priority order):
/// - If ANY agent has `waitingForUser` OR permission pending → ❓ (most actionable)
/// - If ANY agent has `working` or `waitingForAgent` → animated braille spinner
/// - If ALL agents are `idle` → ✓
final consoleTitleProvider = Provider<String>((ref) {
  final projectName = ref.watch(projectNameProvider);
  final aggregatedStatus = _getAggregatedStatus(ref);
  final notifier = ref.watch(consoleTitleNotifierProvider.notifier);
  final titleState = ref.watch(consoleTitleNotifierProvider);

  // Manage animation based on status
  switch (aggregatedStatus) {
    case _AggregatedStatus.needsAttention:
      notifier.stopAnimation();
      return '$projectName ❓';

    case _AggregatedStatus.working:
      notifier.startAnimation();
      return '$projectName ${titleState.currentFrame}';

    case _AggregatedStatus.idle:
      notifier.stopAnimation();
      return '$projectName ✓';
  }
});
