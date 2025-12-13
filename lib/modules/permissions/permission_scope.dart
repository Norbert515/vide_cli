import 'dart:async';
import 'dart:collection';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_manager.dart';
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
    state = PermissionQueueState(current: _queue.isEmpty ? null : _queue.first, queueLength: _queue.length);
  }
}

/// Provider for the current permission request state
final permissionStateProvider = StateNotifierProvider<PermissionStateNotifier, PermissionQueueState>(
  (ref) => PermissionStateNotifier(),
);

/// A widget that manages permission requests by listening to the PermissionService.
class PermissionScope extends StatefulComponent {
  final Component child;

  const PermissionScope({required this.child, super.key});

  @override
  State<PermissionScope> createState() => _PermissionScopeState();
}

class _PermissionScopeState extends State<PermissionScope> {
  StreamSubscription<PermissionRequest>? _permissionSub;
  bool _listenerSetup = false;
  Set<String> _registeredSessionIds = {};

  @override
  void initState() {
    super.initState();
    // Can't access context.read in initState - will set up in build
  }

  void _setupPermissionHandling(BuildContext context) {
    final permissionService = context.read(permissionServiceProvider);

    // Set up listener only once
    if (!_listenerSetup) {
      _listenerSetup = true;
      _permissionSub = permissionService.requests.listen((request) {
        // Enqueue the permission request
        context.read(permissionStateProvider.notifier).enqueueRequest(request);
      });
    }

    // Get ALL agent IDs from the network - each agent is a separate Claude process
    // with its own session ID, so we need to register port files for all of them
    final networkState = context.read(agentNetworkManagerProvider);
    final allAgentIds = networkState.currentNetwork?.agents.map((a) => a.id).toSet() ?? {};

    // Find new agents that aren't registered yet
    final newAgentIds = allAgentIds.difference(_registeredSessionIds);

    if (newAgentIds.isNotEmpty) {
      // Start service with first agent if not started yet
      if (_registeredSessionIds.isEmpty && newAgentIds.isNotEmpty) {
        final firstAgentId = newAgentIds.first;
        permissionService.start(sessionId: firstAgentId, permissionMode: 'acceptEdits');
        _registeredSessionIds.add(firstAgentId);

        // Register remaining new agents
        for (final agentId in newAgentIds.skip(1)) {
          permissionService.registerAdditionalSession(agentId);
          _registeredSessionIds.add(agentId);
        }
      } else {
        // Service already running, just register new agents
        for (final agentId in newAgentIds) {
          permissionService.registerAdditionalSession(agentId);
          _registeredSessionIds.add(agentId);
        }
      }
    }
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    // Watch network state so we rebuild when it changes
    context.watch(agentNetworkManagerProvider);

    // Set up/update permission handling
    _setupPermissionHandling(context);

    // Just return the child - no more Stack overlay
    return component.child;
  }
}
