import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/pages/home_page.dart';
import 'package:vide_cli/modules/agent_network/state/console_title_provider.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/setup/setup_scope.dart';
import 'package:vide_cli/modules/setup/welcome_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/services/sentry_service.dart';

/// Provider for left sidebar focus state, shared across the app.
/// Pages can update this to give focus to the sidebar.
/// When focused, the sidebar expands; when unfocused, it collapses.
final sidebarFocusProvider = StateProvider<bool>((ref) => false);

/// Provider for right sidebar (git) focus state.
/// When true, the git sidebar is focused and receives keyboard input.
final gitSidebarFocusProvider = StateProvider<bool>((ref) => false);

/// Provider for IDE mode state. When true, the team sidebar is shown.
/// Initialized from global settings and can be toggled via /ide command.
final ideModeEnabledProvider = StateProvider<bool>((ref) {
  final configManager = ref.read(videConfigManagerProvider);
  return configManager.readGlobalSettings().ideModeEnabled;
});

/// Provider for file preview path. When set, file preview is shown.
/// Null means no file preview is open.
final filePreviewPathProvider = StateProvider<String?>((ref) => null);

/// Provider to track whether we're on the home page.
/// When true, the agent sidebar is hidden even if IDE mode is enabled.
final isOnHomePageProvider = StateProvider<bool>((ref) => true);

/// Manual override for the current repository path.
/// When set, this takes precedence over the agent network's effective working directory.
final repoPathOverrideProvider = StateProvider<String?>((ref) => null);

/// Provider for current repository path. Uses manual override if set,
/// otherwise uses effective working directory from the agent network
/// (accounts for worktrees), or falls back to Directory.current.path.
final currentRepoPathProvider = Provider<String>((ref) {
  // Manual override takes precedence
  final override = ref.watch(repoPathOverrideProvider);
  if (override != null) {
    return override;
  }
  // Otherwise use agent network's effective directory
  final networkManager = ref.watch(agentNetworkManagerProvider.notifier);
  return networkManager.effectiveWorkingDirectory;
});

/// Provider override for canUseToolCallbackFactory that bridges PermissionService to ClaudeClient.
///
/// This provider creates callbacks that can be passed to ClaudeClient.create() for
/// permission checking via the control protocol.
final _canUseToolCallbackFactoryOverride = canUseToolCallbackFactoryProvider.overrideWith((ref) {
  final permissionService = ref.read(permissionServiceProvider);
  return (PermissionCallbackContext ctx) {
    return (toolName, input, context) async {
      return permissionService.checkToolPermission(toolName, input, context, cwd: ctx.cwd);
    };
  };
});

Future<void> main(List<String> args, {List<Override> overrides = const []}) async {
  // Initialize Sentry and set up nocterm error handler
  await SentryService.init();

  // Create provider container with overrides from entry point and permission callback
  // Note: videoCoreProvider is overridden using Late pattern since it needs the container
  late final VideCore videCore;
  final container = ProviderContainer(
    overrides: [
      _canUseToolCallbackFactoryOverride,
      // Override videoCoreProvider - uses late initialization since it needs container
      videoCoreProvider.overrideWith((ref) => videCore),
      ...overrides,
    ],
  );

  // Create VideCore from the existing container (enables public API usage)
  videCore = VideCore.fromContainer(container);

  // Initialize PostHog analytics
  final configManager = container.read(videConfigManagerProvider);
  await PostHogService.init(configManager);
  PostHogService.appStarted();

  // Note: Pending updates are applied by the wrapper script at ~/.local/bin/vide
  // before launching the actual binary. The version indicator shows "ready" when
  // an update has been downloaded and will be applied on next launch.

  await container.read(agentNetworksStateNotifierProvider.notifier).init();

  await runApp(
    ProviderScope(
      parent: container,
      child: VideApp(container: container),
    ),
  );
}

class VideApp extends StatelessComponent {
  final ProviderContainer container;

  VideApp({required this.container});

  @override
  Component build(BuildContext context) {
    // Get explicit theme if set, otherwise null for auto-detect
    final explicitTheme = context.watch(explicitThemeProvider);

    return NoctermApp(
      title: context.watch(consoleTitleProvider),
      // Pass explicit theme if set, otherwise NoctermApp auto-detects
      theme: explicitTheme,
      child: explicitTheme != null
          // If we have an explicit theme, wrap with matching VideTheme
          ? VideTheme(data: VideThemeData.fromBrightness(explicitTheme), child: _VideAppContent())
          // Otherwise, use auto-detection
          : VideTheme.auto(child: _VideAppContent()),
    );
  }
}

/// Internal widget that handles the app content.
/// Separated to allow watching providers that depend on theme being set up.
class _VideAppContent extends StatelessComponent {
  // GlobalKey to keep Navigator stable
  static final _navigatorKey = GlobalKey();

  @override
  Component build(BuildContext context) {
    // Navigator at top level so dialogs render on top of everything.
    // Each page wraps itself with VideScaffold as needed.
    return WelcomeScope(
      child: SetupScope(
        child: Navigator(
          key: _navigatorKey,
          home: HomePage(),
          // Disable Navigator's ESC handling - pages handle it
          popBehavior: PopBehavior(escapeEnabled: false),
        ),
      ),
    );
  }
}
