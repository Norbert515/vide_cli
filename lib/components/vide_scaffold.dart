import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/main.dart'
    show
        ideModeEnabledProvider,
        sidebarFocusProvider,
        filePreviewPathProvider,
        isOnHomePageProvider;
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/agent_network/components/agent_sidebar.dart';
import 'package:vide_cli/components/file_preview_overlay.dart';
import 'package:vide_cli/modules/toast/components/toast_overlay.dart';
import 'package:vide_cli/components/version_indicator.dart';
import 'package:vide_core/api.dart';

/// Provider to expose the current sidebar width for pages to read.
/// This allows pages to know how much space the sidebar takes without coupling.
final sidebarWidthProvider = StateProvider<double>((ref) => 0.0);

/// A scaffold that provides the standard Vide layout with:
/// - Optional left sidebar (agent list)
/// - Main content area
/// - Proper layering so dialogs overlay sidebars
///
/// The key insight: wrap ALL content (sidebars + main) inside the Navigator's
/// home page. This way, the Navigator's dialogs render on top of everything.
///
/// Usage in main.dart:
/// ```dart
/// Navigator(
///   home: VideScaffold(
///     child: HomePage(),
///   ),
/// )
/// ```
class VideScaffold extends StatefulComponent {
  /// The main content to display in the center area.
  final Component child;

  /// Width of the left sidebar when expanded.
  final double sidebarWidth;

  /// Minimum terminal width required to show sidebar.
  final double minWidthForSidebar;

  const VideScaffold({
    required this.child,
    this.sidebarWidth = 28,
    this.minWidthForSidebar = 100,
    super.key,
  });

  @override
  State<VideScaffold> createState() => _VideScaffoldState();
}

class _VideScaffoldState extends State<VideScaffold>
    with TickerProviderStateMixin {
  late AnimationController _sidebarController;

  double _currentSidebarWidth = 0.0;
  bool _wasIdeModeEnabled = false;

  @override
  void initState() {
    super.initState();

    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _sidebarController.addListener(() {
      setState(() {
        _currentSidebarWidth = _sidebarController.value * component.sidebarWidth;
      });
      _updateSidebarWidthProvider();
    });

    // Check initial IDE mode state
    final configManager = context.read(videConfigManagerProvider);
    final ideModeEnabled = configManager.readGlobalSettings().ideModeEnabled;
    if (ideModeEnabled) {
      _wasIdeModeEnabled = true;
      _sidebarController.value = 1.0;
      _currentSidebarWidth = component.sidebarWidth;
    }
  }

  void _updateSidebarWidthProvider() {
    context.read(sidebarWidthProvider.notifier).state = _currentSidebarWidth;
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _animateSidebarWidth(double targetWidth) {
    final targetValue = targetWidth / component.sidebarWidth;
    _sidebarController.animateTo(targetValue);
  }

  @override
  Component build(BuildContext context) {
    final ideModeEnabled = context.watch(ideModeEnabledProvider);
    final sidebarFocused = context.watch(sidebarFocusProvider);
    final filePreviewPath = context.watch(filePreviewPathProvider);
    final isOnHomePage = context.watch(isOnHomePageProvider);

    // Hide sidebar on home page
    final showSidebar = ideModeEnabled && !isOnHomePage;

    // Handle IDE mode changes
    if (showSidebar != _wasIdeModeEnabled) {
      _wasIdeModeEnabled = showSidebar;
      if (showSidebar) {
        _animateSidebarWidth(component.sidebarWidth);
      } else {
        _sidebarController.stop();
        _currentSidebarWidth = 0.0;
        _updateSidebarWidthProvider();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final terminalWidth = constraints.maxWidth;
        final hasEnoughWidth = terminalWidth >= component.minWidthForSidebar;
        final effectiveSidebarWidth = hasEnoughWidth ? _currentSidebarWidth : 0.0;

        // Standard Row layout - sidebar + main content
        // This component should be used INSIDE the Navigator, so dialogs
        // rendered by Navigator.showDialog will overlay everything.
        return Stack(
          children: [
            // Main layout: sidebar + content
            Row(
              children: [
                // Left sidebar (hidden on home page)
                if (showSidebar)
                  _buildLeftSidebar(context, effectiveSidebarWidth, sidebarFocused),

                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 1, right: 1, top: 1),
                          child: component.child,
                        ),
                      ),
                      // Bottom bar with version indicator
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
                  ),
                ),
              ],
            ),

            // File preview overlay
            if (filePreviewPath != null)
              FilePreviewOverlay(
                filePath: filePreviewPath,
                onClose: () {
                  context.read(filePreviewPathProvider.notifier).state = null;
                },
              ),

            // Toast notifications
            const ToastOverlay(),
          ],
        );
      },
    );
  }

  Component _buildLeftSidebar(BuildContext context, double width, bool focused) {
    return SizedBox(
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: component.sidebarWidth,
          maxWidth: component.sidebarWidth,
          child: AgentSidebar(
            width: component.sidebarWidth.toInt(),
            focused: focused,
            expanded: true,
            onExitRight: () {
              context.read(sidebarFocusProvider.notifier).state = false;
            },
            onSelectAgent: (agentId) {
              context.read(selectedAgentIdProvider.notifier).state = agentId;
              context.read(sidebarFocusProvider.notifier).state = false;
            },
            onSelectRole: (role) async {
              final session = context.read(currentVideSessionProvider);
              if (session == null) {
                context.read(sidebarFocusProvider.notifier).state = false;
                return;
              }

              final agentType = SpawnableAgentTypeExtension.fromTeamRole(role);
              if (agentType == null) {
                context.read(sidebarFocusProvider.notifier).state = false;
                return;
              }

              final networkState = context.read(agentNetworkManagerProvider);
              final agents = networkState.agents;
              final mainAgent = agents.where((a) => a.type == 'main').firstOrNull;
              if (mainAgent == null) {
                context.read(sidebarFocusProvider.notifier).state = false;
                return;
              }

              final newAgentId = await session.spawnAgent(
                agentType: agentType,
                name: role.substring(0, 1).toUpperCase() + role.substring(1),
                initialPrompt: 'You have been manually spawned by the user. Ask them what they need help with.',
                spawnedBy: mainAgent.id,
              );

              context.read(selectedAgentIdProvider.notifier).state = newAgentId;
              context.read(sidebarFocusProvider.notifier).state = false;
            },
          ),
        ),
      ),
    );
  }
}
