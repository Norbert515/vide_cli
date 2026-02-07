import '../mcp/ask_user_question/ask_user_question_service.dart';
import '../mcp/mcp_server_factory.dart';
import 'agent_network_manager.dart';
import 'agent_network_persistence_manager.dart';
import 'agent_status_registry.dart';
import 'claude_client_factory.dart';
import 'claude_client_registry.dart';
import 'permission_provider.dart';
import 'team_framework_loader.dart';
import 'trigger_service.dart';
import 'vide_config_manager.dart';

/// Per-session dependency container.
///
/// Replaces the Riverpod `ProviderContainer` that was previously created
/// for each session in `VideCore.startSession()`. All services for a single
/// session are wired together here with explicit construction order to handle
/// circular dependencies via getter functions.
class SessionServices {
  final String workingDirectory;
  final VideConfigManager configManager;
  final PermissionHandler permissionHandler;
  final bool dangerouslySkipPermissions;

  late final AgentStatusRegistry statusRegistry;
  late final ClaudeClientRegistry clientRegistry;
  late final AgentNetworkPersistenceManager persistenceManager;
  late final TeamFrameworkLoader teamFrameworkLoader;
  late final AskUserQuestionService askUserQuestionService;
  late final TriggerService triggerService;
  late final McpServerFactory mcpServerFactory;
  late final ClaudeClientFactory clientFactory;
  late final AgentNetworkManager networkManager;

  SessionServices({
    required this.workingDirectory,
    required this.configManager,
    required this.permissionHandler,
    this.dangerouslySkipPermissions = false,
  }) {
    // 1. Simple registries (no dependencies)
    statusRegistry = AgentStatusRegistry();
    clientRegistry = ClaudeClientRegistry();

    // 2. Services that depend only on configManager
    persistenceManager = AgentNetworkPersistenceManager(
      configManager: configManager,
    );
    teamFrameworkLoader = TeamFrameworkLoader(
      workingDirectory: workingDirectory,
    );
    askUserQuestionService = AskUserQuestionService();

    // 3. TriggerService (uses getter for circular dep with networkManager)
    triggerService = TriggerService(
      networkManagerGetter: () => networkManager,
      teamFrameworkLoaderGetter: () => teamFrameworkLoader,
    );

    // 4. McpServerFactory (uses getter for circular dep with networkManager)
    mcpServerFactory = McpServerFactory(
      getNetworkManager: () => networkManager,
      statusRegistry: statusRegistry,
      triggerService: triggerService,
      askUserQuestionService: askUserQuestionService,
    );

    // 5. ClaudeClientFactory (no circular dep)
    clientFactory = ClaudeClientFactoryImpl(
      getWorkingDirectory: () => networkManager.effectiveWorkingDirectory,
      configManager: configManager,
      permissionHandler: permissionHandler,
      mcpServerFactory: mcpServerFactory,
      getDangerouslySkipPermissions: () => dangerouslySkipPermissions,
    );

    // 6. AgentNetworkManager (depends on everything above)
    networkManager = AgentNetworkManager(
      workingDirectory: workingDirectory,
      clientFactory: clientFactory,
      clientRegistry: clientRegistry,
      statusRegistry: statusRegistry,
      persistenceManager: persistenceManager,
      triggerService: triggerService,
      teamFrameworkLoader: teamFrameworkLoader,
    );
  }

  /// Dispose all services.
  void dispose() {
    statusRegistry.dispose();
    clientRegistry.dispose();
    askUserQuestionService.dispose();
  }
}
