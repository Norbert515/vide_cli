import 'dart:async';
import 'dart:collection';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'permission_service.dart';

/// State for permission requests - includes queue and current request
class PermissionQueueState {
  final PermissionRequest? current;
  final int queueLength;

  PermissionQueueState({this.current, this.queueLength = 0});
}

/// State notifier for permission requests with queue support
class PermissionStateNotifier extends StateNotifier<PermissionQueueState> {
  final Queue<PermissionRequest> _queue = Queue<PermissionRequest>();

  PermissionStateNotifier() : super(PermissionQueueState());

  /// Add a permission request to the queue
  void enqueueRequest(PermissionRequest request) {
    _queue.add(request);
    _updateState();
  }

  /// Remove the current request and show the next one
  void dequeueRequest() {
    if (_queue.isNotEmpty) {
      _queue.removeFirst();
    }
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
    StateNotifierProvider<PermissionStateNotifier, PermissionQueueState>(
      (ref) => PermissionStateNotifier(),
    );

/// State for AskUserQuestion requests - includes queue and current request
class AskUserQuestionQueueState {
  final AskUserQuestionRequest? current;
  final int queueLength;

  AskUserQuestionQueueState({this.current, this.queueLength = 0});
}

/// State notifier for AskUserQuestion requests with queue support
class AskUserQuestionStateNotifier
    extends StateNotifier<AskUserQuestionQueueState> {
  final Queue<AskUserQuestionRequest> _queue = Queue<AskUserQuestionRequest>();

  AskUserQuestionStateNotifier() : super(AskUserQuestionQueueState());

  /// Add a request to the queue
  void enqueueRequest(AskUserQuestionRequest request) {
    _queue.add(request);
    _updateState();
  }

  /// Remove the current request and show the next one
  void dequeueRequest() {
    if (_queue.isNotEmpty) {
      _queue.removeFirst();
    }
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
    StateNotifierProvider<
      AskUserQuestionStateNotifier,
      AskUserQuestionQueueState
    >((ref) => AskUserQuestionStateNotifier());

/// A widget that manages permission requests by listening to the PermissionService.
class PermissionScope extends StatefulComponent {
  final Component child;

  const PermissionScope({required this.child, super.key});

  @override
  State<PermissionScope> createState() => _PermissionScopeState();
}

class _PermissionScopeState extends State<PermissionScope> {
  StreamSubscription<PermissionRequest>? _permissionSub;
  StreamSubscription<AskUserQuestionRequest>? _askUserQuestionSub;
  bool _listenerSetup = false;

  @override
  void initState() {
    super.initState();
    // Can't access context.read in initState - will set up in build
  }

  void _setupPermissionHandling(BuildContext context) {
    final permissionService = context.read(permissionServiceProvider);
    final askUserQuestionService = context.read(askUserQuestionServiceProvider);

    // Set up listeners only once
    if (!_listenerSetup) {
      _listenerSetup = true;
      _permissionSub = permissionService.requests.listen((request) {
        context.read(permissionStateProvider.notifier).enqueueRequest(request);
      });
      _askUserQuestionSub = askUserQuestionService.requests.listen((request) {
        context
            .read(askUserQuestionStateProvider.notifier)
            .enqueueRequest(request);
      });
    }
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _askUserQuestionSub?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    // Set up permission handling (subscribes to requests stream)
    _setupPermissionHandling(context);

    // Just return the child - no more Stack overlay
    return component.child;
  }
}
