import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/components/file_preview_overlay.dart';
import 'package:vide_cli/components/git_sidebar.dart';
import 'package:vide_cli/components/mcp_servers_panel.dart';
import 'package:vide_cli/components/toast_overlay.dart';
import 'package:vide_cli/components/version_indicator.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_overview_page.dart';
import 'package:vide_cli/modules/agent_network/state/console_title_provider.dart';
import 'package:vide_cli/modules/setup/setup_scope.dart';
import 'package:vide_cli/modules/setup/welcome_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/api.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/services/sentry_service.dart';

/// Provider for sidebar focus state, shared across the app.
/// Pages can update this to give focus to the sidebar.
/// When focused, the sidebar expands; when unfocused, it collapses.
final sidebarFocusProvider = StateProvider<bool>((ref) => false);

/// Provider for MCP panel focus state
final mcpPanelFocusProvider = StateProvider<bool>((ref) => false);

/// Provider for IDE mode state. When true, the git sidebar is shown.
/// Initialized from global settings and can be toggled via /ide command.
final ideModeEnabledProvider = StateProvider<bool>((ref) {
  final configManager = ref.read(videConfigManagerProvider);
  return configManager.readGlobalSettings().ideModeEnabled;
});

/// Provider for file preview path. When set, file preview is shown.
/// Null means no file preview is open.
final filePreviewPathProvider = StateProvider<String?>((ref) => null);

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

/// Internal widget that handles the app content with optional sidebar.
/// Separated to allow watching providers that depend on theme being set up.
class _VideAppContent extends StatefulComponent {
  @override
  State<_VideAppContent> createState() => _VideAppContentState();
}

class _VideAppContentState extends State<_VideAppContent> {
  // Sidebar animation constants
  static const double _sidebarWidth = 30.0;
  static const int _animationSteps = 8;
  static const Duration _animationStepDuration = Duration(milliseconds: 20);

  // MCP panel constants
  static const double _mcpPanelWidth = 32.0;

  // Minimum terminal width to show sidebars (main content needs ~80 chars)
  static const double _minWidthForSidebars = 120.0;

  // Animation state
  double _currentSidebarWidth = 0.0;
  Timer? _animationTimer;
  bool _wasIdeModeEnabled = false;

  // MCP panel animation state
  double _currentMcpPanelWidth = 0.0;
  Timer? _mcpPanelAnimationTimer;
  bool _wasMcpPanelVisible = false;

  @override
  void initState() {
    super.initState();
    final ideModeEnabled = context.read(ideModeEnabledProvider);
    _currentSidebarWidth = ideModeEnabled ? _sidebarWidth : 0.0;
    _currentMcpPanelWidth = ideModeEnabled ? _mcpPanelWidth : 0.0;
    _wasIdeModeEnabled = ideModeEnabled;
    _wasMcpPanelVisible = ideModeEnabled;
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _mcpPanelAnimationTimer?.cancel();
    super.dispose();
  }

  void _animateSidebarWidth(double targetWidth) {
    _animationTimer?.cancel();
    final startWidth = _currentSidebarWidth;
    final delta = (targetWidth - startWidth) / _animationSteps;
    var step = 0;

    _animationTimer = Timer.periodic(_animationStepDuration, (timer) {
      step++;
      if (step >= _animationSteps) {
        timer.cancel();
        setState(() => _currentSidebarWidth = targetWidth);
      } else {
        setState(() => _currentSidebarWidth = startWidth + (delta * step));
      }
    });
  }

  void _animateMcpPanelWidth(double targetWidth) {
    _mcpPanelAnimationTimer?.cancel();
    final startWidth = _currentMcpPanelWidth;
    final delta = (targetWidth - startWidth) / _animationSteps;
    var step = 0;

    _mcpPanelAnimationTimer = Timer.periodic(_animationStepDuration, (timer) {
      step++;
      if (step >= _animationSteps) {
        timer.cancel();
        setState(() => _currentMcpPanelWidth = targetWidth);
      } else {
        setState(() => _currentMcpPanelWidth = startWidth + (delta * step));
      }
    });
  }

  @override
  Component build(BuildContext context) {
    // Check if IDE mode is enabled (reactive to /ide command)
    final ideModeEnabled = context.watch(ideModeEnabledProvider);

    // Animate sidebar when IDE mode changes
    if (ideModeEnabled != _wasIdeModeEnabled) {
      _wasIdeModeEnabled = ideModeEnabled;
      _animateSidebarWidth(ideModeEnabled ? _sidebarWidth : 0.0);
    }

    // Watch sidebar focus state and file preview path
    final sidebarFocused = context.watch(sidebarFocusProvider);
    final filePreviewPath = context.watch(filePreviewPathProvider);

    // Watch MCP panel state - use initial client, show panel from start in IDE mode
    final initialClient = context.watch(videoCoreProvider).initialClient;
    final mcpPanelFocused = context.watch(mcpPanelFocusProvider);
    final showMcpPanel = ideModeEnabled;

    // Animate MCP panel when visibility changes
    if (showMcpPanel != _wasMcpPanelVisible) {
      _wasMcpPanelVisible = showMcpPanel;
      _animateMcpPanelWidth(showMcpPanel ? _mcpPanelWidth : 0.0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if terminal is wide enough for sidebars
        final terminalWidth = constraints.maxWidth;
        final hasEnoughWidth = terminalWidth >= _minWidthForSidebars;

        return _buildMainLayout(
          context,
          ideModeEnabled: ideModeEnabled,
          sidebarFocused: sidebarFocused,
          filePreviewPath: filePreviewPath,
          initialClient: initialClient,
          mcpPanelFocused: mcpPanelFocused,
          showMcpPanel: showMcpPanel,
          hasEnoughWidth: hasEnoughWidth,
        );
      },
    );
  }

  Component _buildMainLayout(
    BuildContext context, {
    required bool ideModeEnabled,
    required bool sidebarFocused,
    required String? filePreviewPath,
    required InitialClaudeClient initialClient,
    required bool mcpPanelFocused,
    required bool showMcpPanel,
    required bool hasEnoughWidth,
  }) {
    // Main navigator content
    final navigatorContent = Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 1, right: 1, top: 1),
            child: WelcomeScope(
              child: SetupScope(
                child: Navigator(
                  home: NetworksOverviewPage(),
                  // Always disable Navigator's ESC handling to prevent race conditions
                  // with GitSidebar's ESC handling when file preview is open
                  popBehavior: PopBehavior(escapeEnabled: false),
                ),
              ),
            ),
          ),
        ),
        // Bottom bar with version indicator in the right corner
        Padding(
          padding: EdgeInsets.only(left: 1, right: 1, bottom: 1),
          child: Row(
            children: [
              Expanded(child: SizedBox()),
              VersionIndicator(),
            ],
          ),
        ),
      ],
    );

    // Determine effective sidebar width - 0 when terminal is too narrow
    final effectiveSidebarWidth = hasEnoughWidth ? _currentSidebarWidth : 0.0;

    return Row(
      children: [
        // Always keep sidebar SizedBox in tree to maintain stable widget structure.
        // When sidebar is conditionally removed/added, it shifts widget positions
        // in the Row, causing the Navigator to be recreated and losing the route stack.
        SizedBox(
          width: effectiveSidebarWidth,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: _sidebarWidth,
              maxWidth: _sidebarWidth,
              child: GitSidebar(
                width: _sidebarWidth.toInt(),
                focused: sidebarFocused,
                expanded: true, // Sidebar is always expanded in IDE mode
                repoPath: context.watch(currentRepoPathProvider),
                onExitRight: () {
                  context.read(sidebarFocusProvider.notifier).state = false;
                },
                onSendMessage: (message) {
                  // Send message to the main agent in the current network
                  final networkState = context.read(agentNetworkManagerProvider);
                  final mainAgentId = networkState.currentNetwork?.agentIds.firstOrNull;
                  if (mainAgentId != null) {
                    context.read(agentNetworkManagerProvider.notifier).sendMessage(mainAgentId, Message(text: message));
                  }
                },
                onSwitchWorktree: (path) {
                  // Switch to the selected worktree directory
                  context.read(repoPathOverrideProvider.notifier).state = path;
                  // Also update the agent network's working directory
                  context.read(agentNetworkManagerProvider.notifier).setWorktreePath(path);
                },
              ),
            ),
          ),
        ),
        // Main content: navigator is always in tree, file preview overlays it
        // This prevents Navigator from being recreated when file preview closes
        Expanded(
          child: Stack(
            children: [
              // Navigator is always mounted to preserve route stack
              navigatorContent,
              // File preview overlays the navigator when open
              if (filePreviewPath != null)
                FilePreviewOverlay(
                  filePath: filePreviewPath,
                  onClose: () {
                    context.read(filePreviewPathProvider.notifier).state = null;
                  },
                ),
              // Toast notifications overlay everything
              const ToastOverlay(),
            ],
          ),
        ),
        // MCP Servers panel on the right - always in tree for stable widget structure
        SizedBox(
          width: hasEnoughWidth ? _currentMcpPanelWidth : 0.0,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topRight,
              minWidth: _mcpPanelWidth,
              maxWidth: _mcpPanelWidth,
              child: McpServersPanel(
                initialClient: initialClient,
                width: _mcpPanelWidth,
                focused: mcpPanelFocused,
                expanded: true,
                onExitLeft: () {
                  context.read(mcpPanelFocusProvider.notifier).state = false;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
