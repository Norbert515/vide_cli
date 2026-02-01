import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/main.dart'
    show
        sidebarFocusProvider,
        gitSidebarFocusProvider,
        gitSidebarEnabledProvider,
        currentDirIsGitRepoProvider,
        filePreviewPathProvider,
        isOnHomePageProvider,
        repoPathOverrideProvider,
        currentRepoPathProvider;
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/agent_network/components/agent_sidebar.dart';
import 'package:vide_cli/modules/git/git_sidebar.dart';
import 'package:vide_cli/components/file_preview_overlay.dart';
import 'package:vide_cli/modules/toast/components/toast_overlay.dart';
import 'package:vide_cli/components/version_indicator.dart';
import 'package:vide_core/vide_core.dart';

/// Provider to expose the current sidebar width for pages to read.
/// This allows pages to know how much space the sidebar takes without coupling.
final sidebarWidthProvider = StateProvider<double>((ref) => 0.0);

/// A scaffold that provides the standard Vide layout with:
/// - Optional left sidebar (agent list)
/// - Main content area
/// - Optional right sidebar (git status)
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

  /// Width of the right (git) sidebar when shown.
  final double gitSidebarWidth;

  /// Minimum terminal width required to show sidebar.
  final double minWidthForSidebar;

  const VideScaffold({
    required this.child,
    this.sidebarWidth = 28,
    this.gitSidebarWidth = 30,
    this.minWidthForSidebar = 100,
    super.key,
  });

  @override
  State<VideScaffold> createState() => _VideScaffoldState();
}

class _VideScaffoldState extends State<VideScaffold> {
  String? _currentFilePreviewPath;
  bool _dialogShowing = false;

  void _showFilePreviewDialog(BuildContext context, String filePath) {
    if (_dialogShowing) return;
    _dialogShowing = true;

    Navigator.of(context)
        .showDialog(
          barrierDismissible: true,
          builder: (dialogContext) => FilePreviewOverlay(
            filePath: filePath,
            onClose: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        )
        .then((_) {
          _dialogShowing = false;
          // Clear the provider when dialog is closed
          if (mounted) {
            context.read(filePreviewPathProvider.notifier).state = null;
          }
        });
  }

  @override
  Component build(BuildContext context) {
    final sidebarFocused = context.watch(sidebarFocusProvider);
    final gitSidebarFocused = context.watch(gitSidebarFocusProvider);
    final gitSidebarEnabled = context.watch(gitSidebarEnabledProvider);
    final isGitRepo = context.watch(currentDirIsGitRepoProvider);
    final filePreviewPath = context.watch(filePreviewPathProvider);
    final isOnHomePage = context.watch(isOnHomePageProvider);
    final repoPath = context.watch(currentRepoPathProvider);

    // Git sidebar shows only if setting is enabled AND we're in a git repo
    final showGitSidebar = gitSidebarEnabled && isGitRepo;

    // Show file preview dialog when path changes
    if (filePreviewPath != null && filePreviewPath != _currentFilePreviewPath) {
      _currentFilePreviewPath = filePreviewPath;
      // Schedule the dialog to show after this build
      Future.microtask(() {
        if (mounted) {
          _showFilePreviewDialog(context, filePreviewPath);
        }
      });
    } else if (filePreviewPath == null) {
      _currentFilePreviewPath = null;
    }

    // Show sidebars on execution page (always), hide on home page
    final showSidebars = !isOnHomePage;

    return LayoutBuilder(
      builder: (context, constraints) {
        final terminalWidth = constraints.maxWidth;
        final hasEnoughWidth = terminalWidth >= component.minWidthForSidebar;
        final effectiveSidebarWidth = (showSidebars && hasEnoughWidth)
            ? component.sidebarWidth
            : 0.0;
        final effectiveGitSidebarWidth = (showSidebars && hasEnoughWidth && showGitSidebar)
            ? component.gitSidebarWidth
            : 0.0;

        // Update the provider so pages can know the sidebar width
        context.read(sidebarWidthProvider.notifier).state =
            effectiveSidebarWidth;

        // Standard Row layout - left sidebar + main content + right sidebar
        // This component should be used INSIDE the Navigator, so dialogs
        // rendered by Navigator.showDialog will overlay everything.
        final mainLayout = Row(
          children: [
            // Left sidebar (hidden on home page)
            if (showSidebars)
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

            // Right sidebar - Git status (hidden on home page, or if disabled/not git repo)
            if (showSidebars && showGitSidebar)
              _buildRightSidebar(
                context,
                effectiveGitSidebarWidth,
                gitSidebarFocused,
                repoPath,
              ),
          ],
        );

        return Stack(
          children: [
            // Main layout: sidebar + content + git sidebar
            mainLayout,

            // Toast notifications (stays in Stack as it doesn't need keyboard focus)
            const ToastOverlay(),
          ],
        );
      },
    );
  }

  Component _buildLeftSidebar(
    BuildContext context,
    double width,
    bool focused,
  ) {
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
          ),
        ),
      ),
    );
  }

  Component _buildRightSidebar(
    BuildContext context,
    double width,
    bool focused,
    String repoPath,
  ) {
    final session = context.read(currentVideSessionProvider);
    return SizedBox(
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topRight,
          minWidth: component.gitSidebarWidth,
          maxWidth: component.gitSidebarWidth,
          child: GitSidebar(
            width: component.gitSidebarWidth.toInt(),
            focused: focused,
            expanded: true,
            repoPath: repoPath,
            onExitLeft: () {
              // Left arrow from git sidebar - unfocus (go back to main content)
              context.read(gitSidebarFocusProvider.notifier).state = false;
            },
            onSendMessage: (message) {
              // Send message to current agent's chat
              final selectedAgentId = context.read(selectedAgentIdProvider);
              if (selectedAgentId != null) {
                session?.sendMessage(
                  Message.text(message),
                  agentId: selectedAgentId,
                );
              }
            },
            onSwitchWorktree: (path) async {
              // Update the repo path override and session's worktree path
              context.read(repoPathOverrideProvider.notifier).state = path;
              final session = context.read(currentVideSessionProvider);
              await session?.setWorktreePath(path);
            },
          ),
        ),
      ),
    );
  }
}
