/// Shared storage for response start times per agent (persists across tab switches)
/// Used by both RunningAgentsBar and NetworkExecutionPage
class AgentResponseTimes {
  static final Map<String, DateTime> _times = {};

  /// Get the response start time for an agent, or null if not processing
  static DateTime? get(String agentId) => _times[agentId];

  /// Set the response start time for an agent (only if not already set)
  static void startIfNeeded(String agentId) {
    _times.putIfAbsent(agentId, () => DateTime.now());
  }

  /// Clear the response start time for an agent
  static void clear(String agentId) {
    _times.remove(agentId);
  }
}
