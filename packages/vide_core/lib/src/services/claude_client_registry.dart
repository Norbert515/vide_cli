import 'dart:async';

import 'package:claude_sdk/claude_sdk.dart';

/// Registry that tracks ClaudeClient instances for all agents in a session.
///
/// Replaces the Riverpod `claudeManagerProvider` (StateNotifierProvider)
/// and `claudeProvider` (Provider.family).
class ClaudeClientRegistry {
  final Map<String, ClaudeClient> _clients = {};
  final _controller = StreamController<ClaudeClientRegistryChange>.broadcast(
    sync: true,
  );

  /// Stream of registry change events.
  Stream<ClaudeClientRegistryChange> get changes => _controller.stream;

  /// Get a client by agent ID. Returns null if not found.
  ClaudeClient? operator [](String agentId) => _clients[agentId];

  /// Get all registered clients as a map.
  Map<String, ClaudeClient> get all => Map.unmodifiable(_clients);

  /// Add a client for an agent.
  void addAgent(String agentId, ClaudeClient client) {
    _clients[agentId] = client;
    _controller.add(
      ClaudeClientRegistryChange(
        agentId: agentId,
        type: ClaudeClientChangeType.added,
      ),
    );
  }

  /// Remove a client for an agent.
  void removeAgent(String agentId) {
    _clients.remove(agentId);
    _controller.add(
      ClaudeClientRegistryChange(
        agentId: agentId,
        type: ClaudeClientChangeType.removed,
      ),
    );
  }

  /// Dispose the registry and close the stream.
  void dispose() {
    _controller.close();
  }
}

enum ClaudeClientChangeType { added, removed }

class ClaudeClientRegistryChange {
  final String agentId;
  final ClaudeClientChangeType type;

  const ClaudeClientRegistryChange({required this.agentId, required this.type});
}
