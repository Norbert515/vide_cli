import 'package:riverpod/riverpod.dart';
import '../claude/agent_client_factory_registry.dart';
import '../permissions/permission_provider.dart';
import 'vide_config_manager.dart';

/// Configuration values that must be provided by the UI layer.
///
/// Replaces the separate abstract providers (workingDirProvider,
/// videConfigManagerProvider, permissionHandlerProvider) with a single,
/// compile-time-checked configuration object.
class VideCoreConfig {
  final String workingDirectory;
  final VideConfigManager configManager;
  final PermissionHandler permissionHandler;
  final bool dangerouslySkipPermissions;

  /// Optional override for the agent client factory registry.
  ///
  /// When null (default), a registry with both [ClaudeAgentClientFactory] and
  /// [CodexAgentClientFactory] is created automatically by the
  /// [agentNetworkManagerProvider]. Set this to provide a custom registry
  /// (e.g., for testing).
  final AgentClientFactoryRegistry? factoryRegistry;

  const VideCoreConfig({
    required this.workingDirectory,
    required this.configManager,
    required this.permissionHandler,
    this.dangerouslySkipPermissions = false,
    this.factoryRegistry,
  });
}

/// Provider for vide_core configuration. MUST be overridden by UI layer.
final videCoreConfigProvider = Provider<VideCoreConfig>((ref) {
  throw UnimplementedError(
    'videCoreConfigProvider must be overridden by the UI layer (TUI or server). '
    'Override it with a VideCoreConfig instance in your ProviderContainer.',
  );
});
