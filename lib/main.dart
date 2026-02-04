import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/pages/home_page.dart';
import 'package:vide_cli/modules/agent_network/state/console_title_provider.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/setup/setup_scope.dart';
import 'package:vide_cli/modules/setup/welcome_scope.dart';
import 'package:vide_cli/modules/remote/remote_config.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/services/sentry_service.dart';

export 'package:vide_cli/modules/remote/remote_config.dart';

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

/// Provider for git sidebar setting. When true, the git sidebar will show
/// (if the current directory is a git repo).
final gitSidebarEnabledProvider = StateProvider<bool>((ref) {
  final configManager = ref.read(videConfigManagerProvider);
  return configManager.readGlobalSettings().gitSidebarEnabled;
});

/// Provider for daemon mode setting. When true, sessions run on a persistent daemon.
/// Initialized from global settings and can be toggled in settings.
final daemonModeEnabledProvider = StateProvider<bool>((ref) {
  final configManager = ref.read(videConfigManagerProvider);
  return configManager.readGlobalSettings().daemonModeEnabled;
});

/// Provider that checks if the current repo path is a git repository.
/// Returns true if .git directory exists in the current or any parent directory.
final currentDirIsGitRepoProvider = Provider<bool>((ref) {
  final repoPath = ref.watch(currentRepoPathProvider);
  return _isGitRepo(repoPath);
});

/// Check if a directory is inside a git repository.
bool _isGitRepo(String path) {
  var dir = Directory(path);
  while (true) {
    final gitDir = Directory('${dir.path}/.git');
    if (gitDir.existsSync()) {
      return true;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      // Reached root
      return false;
    }
    dir = parent;
  }
}

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
/// otherwise uses effective working directory from the current session
/// (accounts for worktrees), or falls back to Directory.current.path.
final currentRepoPathProvider = Provider<String>((ref) {
  // Manual override takes precedence
  final override = ref.watch(repoPathOverrideProvider);
  if (override != null) {
    return override;
  }
  // Otherwise use session's working directory
  final session = ref.watch(currentVideSessionProvider);
  return session?.workingDirectory ?? Directory.current.path;
});

/// Global permission handler for late session binding.
///
/// This is used by the TUI to enable permission checking. After a network is
/// created and wrapped as a session, call `setSession()` to bind it.
final _tuiPermissionHandler = PermissionHandler();

/// Provider for remote configuration. When set, TUI operates in remote mode.
final remoteConfigProvider = StateProvider<RemoteConfig?>((ref) => null);

/// Provider for force local mode flag.
final forceLocalModeProvider = StateProvider<bool>((ref) => false);

/// Provider for force daemon mode flag.
final forceDaemonModeProvider = StateProvider<bool>((ref) => false);

Future<void> main(
  List<String> args, {
  List<Override> overrides = const [],
  RemoteConfig? remoteConfig,
  bool forceLocal = false,
  bool forceDaemon = false,
}) async {
  // Initialize Sentry and set up nocterm error handler
  await SentryService.init();

  // Create provider container with overrides from entry point
  // Note: videoCoreProvider is overridden using Late pattern since it needs the container
  late final VideCore videCore;
  final container = ProviderContainer(
    overrides: [
      // Override videoCoreProvider - uses late initialization since it needs container
      videoCoreProvider.overrideWith((ref) => videCore),
      // Permission handler for late session binding. TUI uses AgentNetworkManager directly,
      // which reads this provider at construction time, so we must override it here.
      permissionHandlerProvider.overrideWithValue(_tuiPermissionHandler),
      // Remote mode configuration
      if (remoteConfig != null)
        remoteConfigProvider.overrideWith((ref) => remoteConfig),
      if (forceLocal) forceLocalModeProvider.overrideWith((ref) => true),
      if (forceDaemon) forceDaemonModeProvider.overrideWith((ref) => true),
      ...overrides,
    ],
  );

  // Create VideCore from the existing container with permission handler.
  // The handler is also passed here for any future VideCore.startSession() calls.
  videCore = VideCore.fromContainer(
    container,
    permissionHandler: _tuiPermissionHandler,
  );

  // Initialize Bashboard analytics (non-blocking, fires app_started when ready)
  final configManager = container.read(videConfigManagerProvider);
  final telemetryEnabled = configManager.isTelemetryEnabled();
  BashboardService.init(configManager, telemetryEnabled: telemetryEnabled);

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
      // Use withOptionalOverride to keep widget tree stable when switching themes
      child: VideTheme.withOptionalOverride(
        data: explicitTheme != null
            ? VideThemeData.fromBrightness(explicitTheme)
            : null,
        child: _VideAppContent(),
      ),
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
    // HomePage now handles both local and daemon modes.
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
