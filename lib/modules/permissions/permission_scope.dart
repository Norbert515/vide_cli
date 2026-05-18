import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/services/sound_service.dart';
import 'permission_service.dart';

/// State for permission requests - includes queue and current request
class PermissionQueueState {
  final PermissionRequest? current;
  final int queueLength;

  PermissionQueueState({this.current, this.queueLength = 0});
}

/// State notifier for permission requests with queue support
class PermissionStateNotifier extends StateNotifier<PermissionQueueState> {
  final List<PermissionRequest> _queue = [];

  PermissionStateNotifier() : super(PermissionQueueState());

  /// Add a permission request to the queue
  void enqueueRequest(PermissionRequest request) {
    _queue.add(request);
    _updateState();
  }

  /// Remove the current request and show the next one
  void dequeueRequest() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
    }
    _updateState();
  }

  /// Remove a specific request by its ID (e.g., when resolved remotely)
  void removeByRequestId(String requestId) {
    _queue.removeWhere((r) => r.requestId == requestId);
    _updateState();
  }

  void _updateState() {
    state = PermissionQueueState(
      current: _queue.isEmpty ? null : _queue.first,
      queueLength: _queue.length,
    );
  }
}

/// Provider for the current permission request state
final permissionStateProvider =
    StateNotifierProvider.family<PermissionStateNotifier, PermissionQueueState, String>(
      (ref, sessionId) => PermissionStateNotifier(),
    );

/// UI request wrapper for AskUserQuestion events
class AskUserQuestionUIRequest {
  final String requestId;
  final List<AskUserQuestionData> questions;

  const AskUserQuestionUIRequest({
    required this.requestId,
    required this.questions,
  });

  /// Create from a session event
  factory AskUserQuestionUIRequest.fromEvent(AskUserQuestionEvent event) {
    return AskUserQuestionUIRequest(
      requestId: event.requestId,
      questions: event.questions,
    );
  }
}

/// State for AskUserQuestion requests - includes queue and current request
class AskUserQuestionQueueState {
  final AskUserQuestionUIRequest? current;
  final int queueLength;

  AskUserQuestionQueueState({this.current, this.queueLength = 0});
}

/// State notifier for AskUserQuestion requests with queue support
class AskUserQuestionStateNotifier
    extends StateNotifier<AskUserQuestionQueueState> {
  final List<AskUserQuestionUIRequest> _queue = [];

  AskUserQuestionStateNotifier() : super(AskUserQuestionQueueState());

  /// Add a request to the queue
  void enqueueRequest(AskUserQuestionUIRequest request) {
    _queue.add(request);
    _updateState();
  }

  /// Remove the current request and show the next one
  void dequeueRequest() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
    }
    _updateState();
  }

  /// Remove a specific request by its ID (e.g., when resolved remotely)
  void removeByRequestId(String requestId) {
    _queue.removeWhere((r) => r.requestId == requestId);
    _updateState();
  }

  void _updateState() {
    state = AskUserQuestionQueueState(
      current: _queue.isEmpty ? null : _queue.first,
      queueLength: _queue.length,
    );
  }
}

/// Provider for the current AskUserQuestion request state
final askUserQuestionStateProvider =
    StateNotifierProvider.family<
      AskUserQuestionStateNotifier,
      AskUserQuestionQueueState,
      String
    >((ref, sessionId) => AskUserQuestionStateNotifier());

/// UI request wrapper for PlanApproval events
class PlanApprovalUIRequest {
  final String requestId;
  final String planContent;
  final List<Map<String, dynamic>>? allowedPrompts;

  const PlanApprovalUIRequest({
    required this.requestId,
    required this.planContent,
    this.allowedPrompts,
  });

  /// Create from a session event
  factory PlanApprovalUIRequest.fromEvent(PlanApprovalRequestEvent event) {
    return PlanApprovalUIRequest(
      requestId: event.requestId,
      planContent: event.planContent,
      allowedPrompts: event.allowedPrompts,
    );
  }
}

/// State for plan approval requests - includes queue and current request
class PlanApprovalQueueState {
  final PlanApprovalUIRequest? current;
  final int queueLength;

  PlanApprovalQueueState({this.current, this.queueLength = 0});
}

/// State notifier for plan approval requests with queue support
class PlanApprovalStateNotifier extends StateNotifier<PlanApprovalQueueState> {
  final List<PlanApprovalUIRequest> _queue = [];

  PlanApprovalStateNotifier() : super(PlanApprovalQueueState());

  /// Add a request to the queue
  void enqueueRequest(PlanApprovalUIRequest request) {
    _queue.add(request);
    _updateState();
  }

  /// Remove the current request and show the next one
  void dequeueRequest() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
    }
    _updateState();
  }

  /// Remove a specific request by its ID (e.g., when resolved remotely)
  void removeByRequestId(String requestId) {
    _queue.removeWhere((r) => r.requestId == requestId);
    _updateState();
  }

  void _updateState() {
    state = PlanApprovalQueueState(
      current: _queue.isEmpty ? null : _queue.first,
      queueLength: _queue.length,
    );
  }
}

/// Provider for the current plan approval request state
final planApprovalStateProvider =
    StateNotifierProvider.family<PlanApprovalStateNotifier, PlanApprovalQueueState, String>(
      (ref, sessionId) => PlanApprovalStateNotifier(),
    );

/// A widget that manages permission requests by listening to VideSession events.
///
/// All permission requests (both local and remote) flow through the session's
/// event stream as [PermissionRequestEvent] and [AskUserQuestionEvent].
class PermissionScope extends StatefulComponent {
  final VideSession session;
  final Component child;

  const PermissionScope({required this.session, required this.child, super.key});

  @override
  State<PermissionScope> createState() => _PermissionScopeState();
}

class _PermissionScopeState extends State<PermissionScope> {
  StreamSubscription<VideEvent>? _sessionEventSub;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    // Can't access context.read in initState - will set up in build
  }

  /// Sets up listening to session events for permission requests.
  ///
  /// All permission requests flow through the session's event stream,
  /// unifying local and remote/daemon modes.
  void _setupSessionEventHandling(BuildContext context) {
    final session = component.session;
    final sessionId = session.id;

    // If session changed, cancel old subscription
    if (sessionId != _currentSessionId) {
      _sessionEventSub?.cancel();
      _sessionEventSub = null;
      _currentSessionId = sessionId;
    }

    // If already subscribed, skip
    if (_sessionEventSub != null) return;

    final configManager = ProviderScope.containerOf(context)
        .read(videConfigManagerProvider);

    // Subscribe to session events for both permission types
    _sessionEventSub = session.events.listen((event) {
      switch (event) {
        case PermissionRequestEvent():
          final request = PermissionRequest.fromEvent(
            event,
            session.state.workingDirectory,
          );
          context
              .read(permissionStateProvider(sessionId).notifier)
              .enqueueRequest(request);
          SoundService.play(SoundType.attentionNeeded, configManager);

        case PermissionResolvedEvent():
          context
              .read(permissionStateProvider(sessionId).notifier)
              .removeByRequestId(event.requestId);

        case AskUserQuestionEvent():
          final request = AskUserQuestionUIRequest.fromEvent(event);
          context
              .read(askUserQuestionStateProvider(sessionId).notifier)
              .enqueueRequest(request);
          SoundService.play(SoundType.attentionNeeded, configManager);

        case PlanApprovalRequestEvent():
          final request = PlanApprovalUIRequest.fromEvent(event);
          context
              .read(planApprovalStateProvider(sessionId).notifier)
              .enqueueRequest(request);
          SoundService.play(SoundType.attentionNeeded, configManager);

        case PlanApprovalResolvedEvent():
          context
              .read(planApprovalStateProvider(sessionId).notifier)
              .removeByRequestId(event.requestId);

        case AskUserQuestionResolvedEvent():
          context
              .read(askUserQuestionStateProvider(sessionId).notifier)
              .removeByRequestId(event.requestId);

        case StatusEvent(status: VideAgentStatus.idle):
          final allIdle = session.state.agents.every(
            (a) => a.status == VideAgentStatus.idle ||
                a.status == VideAgentStatus.waitingForUser,
          );
          if (allIdle) {
            SoundService.play(SoundType.taskComplete, configManager);
          }

        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _sessionEventSub?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    _setupSessionEventHandling(context);

    // Just return the child - no more Stack overlay
    return component.child;
  }
}
