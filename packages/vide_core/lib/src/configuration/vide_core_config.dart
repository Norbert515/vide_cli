import 'package:riverpod/riverpod.dart';
import '../claude/claude_client_factory.dart';
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

  /// Optional override for the agent client factory.
  ///
  /// When null (default), a [ClaudeAgentClientFactory] is created automatically
  /// by the [agentNetworkManagerProvider]. Set this to use a different agent
  /// backend (e.g., [CodexAgentClientFactory] for OpenAI Codex).
  final AgentClientFactory? clientFactory;

  const VideCoreConfig({
    required this.workingDirectory,
    required this.configManager,
    required this.permissionHandler,
    this.dangerouslySkipPermissions = false,
    this.clientFactory,
  });
}

/// Provider for vide_core configuration. MUST be overridden by UI layer.
final videCoreConfigProvider = Provider<VideCoreConfig>((ref) {
  throw UnimplementedError(
    'videCoreConfigProvider must be overridden by the UI layer (TUI or server). '
    'Override it with a VideCoreConfig instance in your ProviderContainer.',
  );
});
