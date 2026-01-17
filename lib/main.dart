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

class _VideAppContentState extends State<_VideAppContent>
    with TickerProviderStateMixin {
  // Sidebar animation constants
  static const double _sidebarWidth = 30.0;
  static const Duration _animationDuration = Duration(milliseconds: 160);

  // MCP panel constants
  static const double _mcpPanelWidth = 32.0;

  // Minimum terminal width to show sidebars (main content needs ~80 chars)
  static const double _minWidthForSidebars = 120.0;

  // GlobalKey to keep Navigator stable when sidebars are added/removed
  final _navigatorKey = GlobalKey();

  // Animation controllers
  late AnimationController _sidebarController;
  late AnimationController _mcpPanelController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _mcpPanelAnimation;

  // Track previous state
  bool _wasIdeModeEnabled = false;
  bool _wasMcpPanelVisible = false;

  // Current animated width values
  double _currentSidebarWidth = 0.0;
  double _currentMcpPanelWidth = 0.0;

  @override
  void initState() {
    super.initState();
    final ideModeEnabled = context.read(ideModeEnabledProvider);

    // Set initial values
    _currentSidebarWidth = ideModeEnabled ? _sidebarWidth : 0.0;
    _currentMcpPanelWidth = ideModeEnabled ? _mcpPanelWidth : 0.0;
    _wasIdeModeEnabled = ideModeEnabled;
    _wasMcpPanelVisible = ideModeEnabled;

    // Initialize sidebar animation controller
    _sidebarController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    // Initialize sidebar animation (will be updated when animating)
    _sidebarAnimation = Tween<double>(
      begin: _currentSidebarWidth,
      end: _currentSidebarWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_sidebarController);
    _sidebarController.addListener(() {
      setState(() {
        _currentSidebarWidth = _sidebarAnimation.value;
      });
    });

    // Initialize MCP panel animation controller
    _mcpPanelController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    // Initialize MCP panel animation (will be updated when animating)
    _mcpPanelAnimation = Tween<double>(
      begin: _currentMcpPanelWidth,
      end: _currentMcpPanelWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_mcpPanelController);
    _mcpPanelController.addListener(() {
      setState(() {
        _currentMcpPanelWidth = _mcpPanelAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _mcpPanelController.dispose();
    super.dispose();
  }

  void _animateSidebarWidth(double targetWidth) {
    _sidebarAnimation = Tween<double>(
      begin: _currentSidebarWidth,
      end: targetWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_sidebarController);
    _sidebarController.forward(from: 0);
  }

  void _animateMcpPanelWidth(double targetWidth) {
    _mcpPanelAnimation = Tween<double>(
      begin: _currentMcpPanelWidth,
      end: targetWidth,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_mcpPanelController);
    _mcpPanelController.forward(from: 0);
  }

  @override
  Component build(BuildContext context) {
    // Check if IDE mode is enabled (reactive to /ide command)
    final ideModeEnabled = context.watch(ideModeEnabledProvider);

    // Handle IDE mode changes
    if (ideModeEnabled != _wasIdeModeEnabled) {
      _wasIdeModeEnabled = ideModeEnabled;
      if (ideModeEnabled) {
        // Animate in when enabling IDE mode
        _animateSidebarWidth(_sidebarWidth);
      } else {
        // Stop animations and reset when disabling - panels will be removed from tree
        _sidebarController.stop();
        _currentSidebarWidth = 0.0;
      }
    }

    // Watch sidebar focus state and file preview path
    final sidebarFocused = context.watch(sidebarFocusProvider);
    final filePreviewPath = context.watch(filePreviewPathProvider);

    // Watch MCP panel state - use initial client, show panel from start in IDE mode
    final initialClient = context.watch(videoCoreProvider).initialClient;
    final mcpPanelFocused = context.watch(mcpPanelFocusProvider);
    final showMcpPanel = ideModeEnabled;

    // Handle MCP panel visibility changes
    if (showMcpPanel != _wasMcpPanelVisible) {
      _wasMcpPanelVisible = showMcpPanel;
      if (showMcpPanel) {
        // Animate in when enabling
        _animateMcpPanelWidth(_mcpPanelWidth);
      } else {
        // Stop animations and reset when disabling - panel will be removed from tree
        _mcpPanelController.stop();
        _currentMcpPanelWidth = 0.0;
      }
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
    // Main navigator content - uses GlobalKey to stay stable when sidebars are added/removed
    final navigatorContent = Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 1, right: 1, top: 1),
            child: WelcomeScope(
              child: SetupScope(
                child: Navigator(
                  key: _navigatorKey,
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
        // Git sidebar - only in widget tree when IDE mode is enabled
        if (ideModeEnabled)
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
        // Main content: navigator uses GlobalKey for stability when sidebars change
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
        // MCP Servers panel - only in widget tree when IDE mode is enabled
        if (ideModeEnabled)
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
