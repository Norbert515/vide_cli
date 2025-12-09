import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';
import '../models/agent_status.dart';
import '../service/agent_network_manager.dart';
import 'agent_status_manager.dart';

/// Provides the project name from the current working directory.
final projectNameProvider = Provider<String>((ref) {
  return path.basename(Directory.current.path);
});

/// Provides the aggregated console title based on the status of all agents in the network.
///
/// Format: "ProjectName <emoji>"
///
/// Status aggregation logic (priority order):
/// - If ANY agent has `waitingForUser` → ❓ (most actionable)
/// - If ANY agent has `working` or `waitingForAgent` → ⚡
/// - If ALL agents are `idle` → ✓
final consoleTitleProvider = Provider<String>((ref) {
  final projectName = ref.watch(projectNameProvider);
  final networkState = ref.watch(agentNetworkManagerProvider);
  final agentIds = networkState.agentIds;

  // No agents = Idle
  if (agentIds.isEmpty) {
    return '$projectName ✓';
  }

  // Collect all agent statuses
  bool hasWaitingForUser = false;
  bool hasWorking = false;
  bool allIdle = true;

  for (final agentId in agentIds) {
    final status = ref.watch(agentStatusProvider(agentId));

    switch (status) {
      case AgentStatus.waitingForUser:
        hasWaitingForUser = true;
        allIdle = false;
        break;
      case AgentStatus.working:
      case AgentStatus.waitingForAgent:
        hasWorking = true;
        allIdle = false;
        break;
      case AgentStatus.idle:
        // Keep checking other agents
        break;
    }

    // Early exit if we found waitingForUser (highest priority)
    if (hasWaitingForUser) {
      break;
    }
  }

  // Return based on priority
  if (hasWaitingForUser) {
    return '$projectName ❓';
  }
  if (hasWorking) {
    return '$projectName ⚡';
  }
  if (allIdle) {
    return '$projectName ✓';
  }

  // Fallback (shouldn't happen)
  return '$projectName ✓';
});
