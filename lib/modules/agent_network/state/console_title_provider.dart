import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';
import '../../permissions/permission_scope.dart';
import 'package:vide_core/vide_core.dart' as api;
import 'vide_session_providers.dart';

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

/// Determines the aggregated status across all agents and permission state.
///
/// Agent status comes from VideAgent.status, which is derived from
/// agentStatusProvider in the data layer (VideSession). The
/// videSessionAgentsProvider (a StreamProvider) triggers rebuilds when
/// status changes.
_AggregatedStatus _getAggregatedStatus(Ref ref) {
  final permissionState = ref.watch(permissionStateProvider);
  final askUserQuestionState = ref.watch(askUserQuestionStateProvider);

  // Watch agents stream — this triggers rebuilds when agent status changes
  final agentsAsync = ref.watch(videSessionAgentsProvider);

  // Check if there's a pending permission request or askUserQuestion
  if (permissionState.current != null || askUserQuestionState.current != null) {
    return _AggregatedStatus.needsAttention;
  }

  final agents = agentsAsync.valueOrNull;
  if (agents == null || agents.isEmpty) {
    return _AggregatedStatus.idle;
  }

  bool hasWorking = false;

  for (final agent in agents) {
    switch (agent.status) {
      case api.VideAgentStatus.waitingForUser:
        return _AggregatedStatus.needsAttention;
      case api.VideAgentStatus.working:
      case api.VideAgentStatus.waitingForAgent:
        hasWorking = true;
        break;
      case api.VideAgentStatus.idle:
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
