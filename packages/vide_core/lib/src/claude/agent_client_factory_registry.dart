import 'claude_client_factory.dart';

/// Registry that maps harness identifiers to their [AgentClientFactory].
///
/// Each agent personality can specify a `harness` (e.g., 'claude-code',
/// 'codex-cli') to select which backend it runs on. The registry resolves
/// the harness name to the appropriate factory.
///
/// Precedence for harness resolution:
///   spawn override > personality default > [defaultHarness]
class AgentClientFactoryRegistry {
  /// Harness identifier for Claude Code (claude_sdk).
  static const claudeCode = 'claude-code';

  /// Harness identifier for Codex CLI (codex_sdk).
  static const codexCli = 'codex-cli';

  final Map<String, AgentClientFactory> _factories;

  /// The harness used when an agent has no explicit harness set.
  final String defaultHarness;

  const AgentClientFactoryRegistry({
    required Map<String, AgentClientFactory> factories,
    required this.defaultHarness,
  }) : _factories = factories;

  /// Get the factory for a harness. Null falls back to [defaultHarness].
  AgentClientFactory getFactory(String? harness) {
    final key = harness ?? defaultHarness;
    final factory = _factories[key];
    if (factory == null) {
      throw ArgumentError(
        'Unknown harness "$key". '
        'Available: ${_factories.keys.join(", ")}',
      );
    }
    return factory;
  }

  /// Whether the given harness supports session forking.
  bool supportsFork(String? harness) => getFactory(harness).supportsFork;
}
