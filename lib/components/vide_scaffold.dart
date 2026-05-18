import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/main.dart'
    show
        gitSidebarEnabledProvider,
        currentDirIsGitRepoProvider,
        filePreviewPathProvider,
        isOnHomePageProvider,
        repoPathOverrideProvider,
        currentRepoPathProvider;
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/agent_network/components/agent_sidebar.dart';
import 'package:vide_cli/modules/git/git_sidebar.dart';
import 'package:vide_cli/modules/git/git_branch_indicator.dart';
import 'package:vide_cli/components/file_preview_overlay.dart';
import 'package:vide_cli/modules/toast/components/toast_overlay.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Which panel currently holds keyboard focus.
enum FocusedPanel { content, leftSidebar, rightSidebar }

/// A scaffold that provides the standard Vide layout with:
/// - Optional left sidebar (agent list)
/// - Main content area
/// - Optional right sidebar (git status)
/// - Proper layering so dialogs overlay sidebars
///
/// The key insight: wrap ALL content (sidebars + main) inside the Navigator's
/// home page. This way, the Navigator's dialogs render on top of everything.
///
/// The [childBuilder] receives focus state so the content can react to sidebar
/// focus changes without needing providers or inherited widgets:
/// - `contentFocused`: true when neither sidebar has keyboard focus
/// - `focusLeftSidebar` / `focusRightSidebar`: callbacks to shift focus
class VideScaffold extends StatefulComponent {
  /// The current session (threaded from NetworkExecutionPage).
  final VideSession session;

  /// The current agents list (streamed from NetworkExecutionPage).
  final List<VideAgent> agents;

  /// Builder for the main content. Receives sidebar focus state so the content
  /// area can adjust (e.g. defocus the text field when a sidebar is focused).
  final Component Function({
    required bool contentFocused,
    required VoidCallback focusLeftSidebar,
    required VoidCallback focusRightSidebar,
  }) childBuilder;

  /// Width of the left sidebar when expanded.
  final double sidebarWidth;

  /// Width of the right (git) sidebar when shown.
  final double gitSidebarWidth;

  /// Minimum terminal width required to show sidebar.
  final double minWidthForSidebar;

  const VideScaffold({
    required this.session,
    required this.agents,
    required this.childBuilder,
    this.sidebarWidth = 28,
    this.gitSidebarWidth = 30,
    this.minWidthForSidebar = 100,
    super.key,
  });

  @override
  State<VideScaffold> createState() => _VideScaffoldState();
}

class _VideScaffoldState extends State<VideScaffold> {
  FocusedPanel _focusedPanel = FocusedPanel.content;
  String? _currentFilePreviewPath;
  bool _dialogShowing = false;

  /// Goal text, updated via direct session stream subscription.
  String _goalText = 'Session';
  StreamSubscription<String>? _goalSub;

  @override
  void initState() {
    super.initState();
    _goalText = component.session.state.goal;
    _goalSub = component.session.stateStream
        .map((s) => s.goal)
        .distinct()
        .listen((goal) {
      if (mounted) setState(() => _goalText = goal);
    });
  }

  @override
  void dispose() {
    _goalSub?.cancel();
    super.dispose();
  }

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
    final theme = VideTheme.of(context);
    final sidebarFocused = _focusedPanel == FocusedPanel.leftSidebar;
    final gitSidebarFocused = _focusedPanel == FocusedPanel.rightSidebar;
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
        final effectiveGitSidebarWidth =
            (showSidebars && hasEnoughWidth && showGitSidebar)
            ? component.gitSidebarWidth
            : 0.0;

        final panelRow = Row(
          children: [
            // Left sidebar with thin divider
            if (showSidebars)
              _buildLeftSidebar(
                context,
                theme,
                effectiveSidebarWidth,
                sidebarFocused,
              ),

            // Main content area
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 1, right: 1, top: 1),
                child: component.childBuilder(
                  contentFocused: _focusedPanel == FocusedPanel.content,
                  focusLeftSidebar: () =>
                      setState(() => _focusedPanel = FocusedPanel.leftSidebar),
                  focusRightSidebar: () =>
                      setState(() => _focusedPanel = FocusedPanel.rightSidebar),
                ),
              ),
            ),

            // Right sidebar with thin divider
            if (showSidebars && showGitSidebar)
              _buildRightSidebar(
                context,
                theme,
                effectiveGitSidebarWidth,
                gitSidebarFocused,
                repoPath,
              ),
          ],
        );

        final mainLayout = Column(
          children: [
            if (showSidebars) _buildTitleBar(context, theme, repoPath),
            Expanded(child: panelRow),
          ],
        );

        return Stack(children: [mainLayout, const ToastOverlay()]);
      },
    );
  }

  Component _buildLeftSidebar(
    BuildContext context,
    VideThemeData theme,
    double width,
    bool focused,
  ) {
    return Row(
      children: [
        SizedBox(
          width: width - 1, // Reserve 1 col for the divider
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: component.sidebarWidth - 1,
              maxWidth: component.sidebarWidth - 1,
              child: AgentSidebar(
                session: component.session,
                agents: component.agents,
                width: (component.sidebarWidth - 1).toInt(),
                focused: focused,
                expanded: true,
                onExitRight: () {
                  setState(() => _focusedPanel = FocusedPanel.content);
                },
                onSelectAgent: (agentId) {
                  context.read(selectedAgentIdProvider(component.session.id).notifier).state =
                      agentId;
                  setState(() => _focusedPanel = FocusedPanel.content);
                },
              ),
            ),
          ),
        ),
        VerticalDivider(
          color: theme.base.outlineVariant,
          style: DividerStyle.single,
        ),
      ],
    );
  }

  Component _buildRightSidebar(
    BuildContext context,
    VideThemeData theme,
    double width,
    bool focused,
    String repoPath,
  ) {
    final session = component.session;
    return Row(
      children: [
        VerticalDivider(
          color: theme.base.outlineVariant,
          style: DividerStyle.single,
        ),
        SizedBox(
          width: width - 1, // Reserve 1 col for the divider
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topRight,
              minWidth: component.gitSidebarWidth - 1,
              maxWidth: component.gitSidebarWidth - 1,
              child: GitSidebar(
                width: (component.gitSidebarWidth - 1).toInt(),
                focused: focused,
                expanded: true,
                repoPath: repoPath,
                onExitLeft: () {
                  setState(() => _focusedPanel = FocusedPanel.content);
                },
                onSendMessage: (message) {
                  final selectedAgentId = context.read(selectedAgentIdProvider(session.id));
                  if (selectedAgentId != null) {
                    session.sendMessage(
                      AgentMessage(text: message),
                      agentId: selectedAgentId,
                    );
                  }
                },
                onSwitchWorktree: (path) async {
                  context.read(repoPathOverrideProvider.notifier).state = path;
                  await session.setWorktreePath(path);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Component _buildTitleBar(
    BuildContext context,
    VideThemeData theme,
    String repoPath,
  ) {
    final session = component.session;
    final primary = theme.base.primary;
    final dimmer = theme.base.onSurface.withOpacity(TextOpacity.tertiary);
    return Container(
      decoration: BoxDecoration(
        border: BoxBorder(bottom: BorderSide(color: theme.base.outlineVariant)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            'VIDE',
            style: TextStyle(color: primary, fontWeight: FontWeight.bold),
          ),
          Text(' \u2502 ', style: TextStyle(color: dimmer)),
          Expanded(
            child: Text(
              _goalText,
              style: TextStyle(
                color: theme.base.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            session.id.length > 8 ? session.id.substring(0, 8) : session.id,
            style: TextStyle(color: dimmer),
          ),
          Text(' \u2502 ', style: TextStyle(color: dimmer)),
          GitBranchIndicator(repoPath: repoPath),
        ],
      ),
    );
  }
}
