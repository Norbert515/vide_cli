import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:vide_mobile/core/theme/app_theme.dart';
import 'package:vide_mobile/core/theme/vide_colors.dart';

import '../services/screenshot_service.dart';
import '../services/voice_input_service.dart';
import '../state/sdk_state.dart';
import 'chat_panel.dart';
import 'file_browser.dart';
import 'git_view.dart';
import 'screenshot_canvas.dart';

/// The top-level tabs.
enum _VideTab { agent, app, tools, project }

/// Embeds your Flutter app inside the Vide dev environment.
///
/// A small tab bar sits above the app with three tabs:
/// - **Agent**: Chat with the AI assistant
/// - **App**: Your actual Flutter app
/// - **Project**: Files and Git browser
///
/// ```dart
/// VideInApp(
///   child: MaterialApp(home: MyHomePage()),
/// )
/// ```
class VideInApp extends StatefulWidget {
  final Widget child;

  const VideInApp({super.key, required this.child});

  static VideInAppController of(BuildContext context) {
    final state = context.findAncestorStateOfType<_VideInAppState>();
    if (state == null) {
      throw FlutterError(
        'VideInApp.of(context) called outside of a VideInApp widget tree.',
      );
    }
    return state._controller;
  }

  @override
  State<VideInApp> createState() => _VideInAppState();
}

class VideInAppController {
  final _VideInAppState _state;

  VideInAppController._(this._state);

  void showAgent() => _state._selectTab(_VideTab.agent);
  void showApp() => _state._selectTab(_VideTab.app);
  void showProject() => _state._selectTab(_VideTab.project);
  Future<void> captureScreenshot() => _state._captureScreenshot();
  VideSdkState get sdkState => _state._sdkState;
}

class _VideInAppState extends State<VideInApp> {
  late final VideSdkState _sdkState;
  late final ScreenshotService _screenshotService;
  late final VoiceInputService _voiceService;
  late final VideInAppController _controller;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  _VideTab _selectedTab = _VideTab.app;

  bool _screenshotMode = false;
  ui.Image? _capturedScreenshot;
  Uint8List? _pendingScreenshotBytes;
  bool _screenshotVisible = false;

  @override
  void initState() {
    super.initState();

    _sdkState = VideSdkState();
    _sdkState.loadConfig();
    _screenshotService = ScreenshotService(
      repaintBoundaryKey: _repaintBoundaryKey,
    );
    _voiceService = VoiceInputService();
    _controller = VideInAppController._(this);
  }

  @override
  void dispose() {
    _sdkState.dispose();
    _voiceService.dispose();
    _capturedScreenshot?.dispose();
    super.dispose();
  }

  void _selectTab(_VideTab tab) {
    setState(() => _selectedTab = tab);
  }

  Future<void> _captureScreenshot() async {
    // Switch to app tab so we capture the app, not the chat.
    final previousTab = _selectedTab;
    if (_selectedTab != _VideTab.app) {
      setState(() => _selectedTab = _VideTab.app);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    try {
      final image = await _screenshotService.capture();
      if (!mounted) return;
      setState(() {
        _capturedScreenshot = image;
        _screenshotMode = true;
        _screenshotVisible = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _screenshotVisible = true);
      });
    } catch (e) {
      if (mounted && previousTab != _VideTab.app) {
        setState(() => _selectedTab = previousTab);
      }
    }
  }

  void _onScreenshotConfirm(Uint8List bytes) {
    _pendingScreenshotBytes = bytes;
    _dismissScreenshotOverlay();
  }

  void _onScreenshotCancel() {
    _dismissScreenshotOverlay();
  }

  void _dismissScreenshotOverlay() {
    setState(() => _screenshotVisible = false);

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _capturedScreenshot?.dispose();
      setState(() {
        _capturedScreenshot = null;
        _screenshotMode = false;
        // Switch back to agent tab so user can type about the screenshot
        _selectedTab = _VideTab.agent;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ListenableBuilder(
        listenable: _sdkState,
        builder: (context, _) {
          if (!_sdkState.isConfigured) {
            return _MaterialShell(
              child: _SetupScreen(sdkState: _sdkState),
            );
          }
          return _buildTabLayout(context);
        },
      ),
    );
  }

  Widget _buildTabLayout(BuildContext context) {
    // Auto-switch to Agent tab when there are pending permissions/approvals
    // so the user sees them (sheets are shown inside the Agent tab's Navigator).
    final hasPendingInteraction = _sdkState.currentPermission != null ||
        _sdkState.pendingPlanApproval != null ||
        _sdkState.pendingAskUserQuestion != null;
    if (hasPendingInteraction && _selectedTab != _VideTab.agent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedTab != _VideTab.agent) {
          setState(() => _selectedTab = _VideTab.agent);
        }
      });
    }

    return _MaterialShell(
      child: Column(
        children: [
          // Tab bar
          _VideTabBar(
            selectedTab: _selectedTab,
            onTabSelected: (tab) => setState(() => _selectedTab = tab),
            sdkState: _sdkState,
          ),

          // Content
          Expanded(
            child: Stack(
              children: [
                // Keep all tabs alive with Offstage so state is preserved
                Offstage(
                  offstage: _selectedTab != _VideTab.agent,
                  child: VideChatPanel(
                    sdkState: _sdkState,
                    voiceService: _voiceService,
                    onScreenshotRequest: _captureScreenshot,
                    pendingScreenshot: _pendingScreenshotBytes,
                    onClearScreenshot: () {
                      setState(() => _pendingScreenshotBytes = null);
                    },
                  ),
                ),
                Offstage(
                  offstage: _selectedTab != _VideTab.app,
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: widget.child,
                  ),
                ),
                Offstage(
                  offstage: _selectedTab != _VideTab.tools,
                  child: const _ToolsView(),
                ),
                Offstage(
                  offstage: _selectedTab != _VideTab.project,
                  child: _ProjectView(sdkState: _sdkState),
                ),

                // Screenshot overlay
                if (_screenshotMode && _capturedScreenshot != null)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _screenshotVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: ScreenshotCanvas(
                        screenshot: _capturedScreenshot!,
                        onConfirm: _onScreenshotConfirm,
                        onCancel: _onScreenshotCancel,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab bar
// =============================================================================

class _VideTabBar extends StatelessWidget {
  final _VideTab selectedTab;
  final ValueChanged<_VideTab> onTabSelected;
  final VideSdkState sdkState;

  const _VideTabBar({
    required this.selectedTab,
    required this.onTabSelected,
    required this.sdkState,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TabItem(
              label: 'Agent',
              icon: Icons.smart_toy_outlined,
              isSelected: selectedTab == _VideTab.agent,
              onTap: () => onTabSelected(_VideTab.agent),
              videColors: videColors,
              trailing: _buildAgentIndicator(context),
            ),
            _TabItem(
              label: 'App',
              icon: Icons.phone_iphone_outlined,
              isSelected: selectedTab == _VideTab.app,
              onTap: () => onTabSelected(_VideTab.app),
              videColors: videColors,
            ),
            _TabItem(
              label: 'Tools',
              icon: Icons.handyman_outlined,
              isSelected: selectedTab == _VideTab.tools,
              onTap: () => onTabSelected(_VideTab.tools),
              videColors: videColors,
            ),
            _TabItem(
              label: 'Project',
              icon: Icons.folder_outlined,
              isSelected: selectedTab == _VideTab.project,
              onTap: () => onTabSelected(_VideTab.project),
              videColors: videColors,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildAgentIndicator(BuildContext context) {
    return ListenableBuilder(
      listenable: sdkState,
      builder: (context, _) {
        final isProcessing = sdkState.videState?.isProcessing ?? false;
        if (!isProcessing) return const SizedBox.shrink();

        final videColors = Theme.of(context).extension<VideThemeColors>()!;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: videColors.accent,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VideThemeColors videColors;
  final Widget? trailing;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.videColors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? videColors.accent : videColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? videColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Project view (Files + Git)
// =============================================================================

class _ProjectView extends StatefulWidget {
  final VideSdkState sdkState;

  const _ProjectView({required this.sdkState});

  @override
  State<_ProjectView> createState() => _ProjectViewState();
}

enum _ProjectSection { files, git }

class _ProjectViewState extends State<_ProjectView> {
  _ProjectSection _section = _ProjectSection.files;

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final client = widget.sdkState.client;
    final workingDir = widget.sdkState.workingDirectory ?? '';

    return Column(
      children: [
        // Files / Git sub-tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              _SubTab(
                label: 'Files',
                icon: Icons.folder_outlined,
                isSelected: _section == _ProjectSection.files,
                onTap: () => setState(() => _section = _ProjectSection.files),
                videColors: videColors,
              ),
              const SizedBox(width: 4),
              _SubTab(
                label: 'Git',
                icon: Icons.commit,
                isSelected: _section == _ProjectSection.git,
                onTap: () => setState(() => _section = _ProjectSection.git),
                videColors: videColors,
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: client != null && workingDir.isNotEmpty
              ? _section == _ProjectSection.files
                  ? FileBrowser(
                      key: ValueKey('files_$workingDir'),
                      client: client,
                      workingDirectory: workingDir,
                    )
                  : GitView(
                      key: ValueKey('git_$workingDir'),
                      client: client,
                      workingDirectory: workingDir,
                    )
              : Center(
                  child: Text(
                    'Not connected',
                    style: TextStyle(color: videColors.textSecondary),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VideThemeColors videColors;

  const _SubTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.videColors,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? videColors.accent : videColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? videColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tools view — developer utilities
// =============================================================================

class _ToolsView extends StatelessWidget {
  const _ToolsView();

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ToolSection(
          title: 'Inspect',
          videColors: videColors,
          children: [
            _ToolTile(
              icon: Icons.account_tree_outlined,
              title: 'Widget Tree',
              subtitle: 'Dump widget tree to console',
              onTap: () => debugDumpApp(),
              videColors: videColors,
              colorScheme: colorScheme,
            ),
            _ToolTile(
              icon: Icons.layers_outlined,
              title: 'Layer Tree',
              subtitle: 'Dump layer tree to console',
              onTap: () => debugDumpLayerTree(),
              videColors: videColors,
              colorScheme: colorScheme,
            ),
            _ToolTile(
              icon: Icons.format_paint_outlined,
              title: 'Render Tree',
              subtitle: 'Dump render tree to console',
              onTap: () => debugDumpRenderTree(),
              videColors: videColors,
              colorScheme: colorScheme,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ToolSection(
          title: 'Overlay',
          videColors: videColors,
          children: [
            _ToggleToolTile(
              icon: Icons.grid_4x4_outlined,
              title: 'Show Layout Bounds',
              subtitle: 'Visualize widget boundaries',
              valueGetter: () => debugPaintSizeEnabled,
              onChanged: (v) {
                debugPaintSizeEnabled = v;
                // Force a repaint
                WidgetsBinding.instance.renderViews.first.markNeedsPaint();
              },
              videColors: videColors,
              colorScheme: colorScheme,
            ),
            _ToggleToolTile(
              icon: Icons.format_paint,
              title: 'Show Paint Baselines',
              subtitle: 'Visualize text baselines',
              valueGetter: () => debugPaintBaselinesEnabled,
              onChanged: (v) {
                debugPaintBaselinesEnabled = v;
                WidgetsBinding.instance.renderViews.first.markNeedsPaint();
              },
              videColors: videColors,
              colorScheme: colorScheme,
            ),
            _ToggleToolTile(
              icon: Icons.touch_app_outlined,
              title: 'Show Pointer Areas',
              subtitle: 'Visualize hit test regions',
              valueGetter: () => debugPaintPointersEnabled,
              onChanged: (v) {
                debugPaintPointersEnabled = v;
                WidgetsBinding.instance.renderViews.first.markNeedsPaint();
              },
              videColors: videColors,
              colorScheme: colorScheme,
            ),
            _ToggleToolTile(
              icon: Icons.palette_outlined,
              title: 'Show Repaint Rainbow',
              subtitle: 'Color regions on repaint',
              valueGetter: () => debugRepaintRainbowEnabled,
              onChanged: (v) {
                debugRepaintRainbowEnabled = v;
                WidgetsBinding.instance.renderViews.first.markNeedsPaint();
              },
              videColors: videColors,
              colorScheme: colorScheme,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ToolSection(
          title: 'Performance',
          videColors: videColors,
          children: [
            _ToggleToolTile(
              icon: Icons.speed_outlined,
              title: 'Performance Overlay',
              subtitle: 'Show GPU/UI thread timings',
              valueGetter: () =>
                  WidgetsApp.showPerformanceOverlayOverride,
              onChanged: (v) {
                WidgetsApp.showPerformanceOverlayOverride = v;
                (context as Element).markNeedsBuild();
              },
              videColors: videColors,
              colorScheme: colorScheme,
            ),
            _ToolTile(
              icon: Icons.timer_outlined,
              title: 'Dump Semantics',
              subtitle: 'Dump semantics tree to console',
              onTap: () => debugDumpSemanticsTree(),
              videColors: videColors,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolSection extends StatelessWidget {
  final String title;
  final VideThemeColors videColors;
  final List<Widget> children;

  const _ToolSection({
    required this.title,
    required this.videColors,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: videColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VideThemeColors videColors;
  final ColorScheme colorScheme;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.videColors,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: videColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: videColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: videColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleToolTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool Function() valueGetter;
  final ValueChanged<bool> onChanged;
  final VideThemeColors videColors;
  final ColorScheme colorScheme;

  const _ToggleToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueGetter,
    required this.onChanged,
    required this.videColors,
    required this.colorScheme,
  });

  @override
  State<_ToggleToolTile> createState() => _ToggleToolTileState();
}

class _ToggleToolTileState extends State<_ToggleToolTile> {
  @override
  Widget build(BuildContext context) {
    final isOn = widget.valueGetter();

    return GestureDetector(
      onTap: () {
        widget.onChanged(!isOn);
        setState(() {});
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: widget.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: widget.videColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: widget.videColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              onChanged: (v) {
                widget.onChanged(v);
                setState(() {});
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Material shell — provides theme, localizations, overlay for all Vide UI
// =============================================================================

class _MaterialShell extends StatelessWidget {
  final Widget child;
  const _MaterialShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      scrollBehavior: const _DesktopDragScrollBehavior(),
      home: Scaffold(body: child),
    );
  }
}

/// Scroll behavior that allows mouse drag to scroll on desktop platforms.
class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.mouse,
      };
}

// =============================================================================
// Setup screen
// =============================================================================

class _SetupScreen extends StatefulWidget {
  final VideSdkState sdkState;

  const _SetupScreen({required this.sdkState});

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _workingDirController = TextEditingController();
  bool _testing = false;
  _SetupTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    final s = widget.sdkState;
    if (s.host != null) _hostController.text = s.host!;
    if (s.port != null) _portController.text = s.port!.toString();
    if (s.workingDirectory != null) {
      _workingDirController.text = s.workingDirectory!;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _workingDirController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final dir = _workingDirController.text.trim();

    if (host.isEmpty || portStr.isEmpty || dir.isEmpty) {
      setState(() {
        _testResult = _SetupTestResult(
          success: false,
          message: 'All fields are required',
        );
      });
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _testResult = _SetupTestResult(
          success: false,
          message: 'Invalid port number',
        );
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final success = await widget.sdkState.testConnection(
      host: host,
      port: port,
    );

    if (!mounted) return;

    if (success) {
      await widget.sdkState.updateConfig(
        host: host,
        port: port,
        workingDirectory: dir,
      );
    } else {
      setState(() {
        _testing = false;
        _testResult = _SetupTestResult(
          success: false,
          message: 'Connection failed — check host and port',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.code,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Vide',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connect to your Vide server to get started.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Host
                Text('Host', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    hintText: 'localhost',
                    prefixIcon: const Icon(Icons.computer_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearResult(),
                ),
                const SizedBox(height: 16),

                // Port
                Text('Port', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(
                  controller: _portController,
                  decoration: InputDecoration(
                    hintText: '8080',
                    prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  onChanged: (_) => _clearResult(),
                ),
                const SizedBox(height: 16),

                // Working directory
                Text(
                  'Working Directory',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _workingDirController,
                  decoration: InputDecoration(
                    hintText: '/path/to/your/project',
                    prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _testAndSave(),
                ),
                const SizedBox(height: 24),

                if (_testResult != null) ...[
                  _buildResultChip(context),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _testing ? null : _testAndSave,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(_testing ? 'Testing...' : 'Test & Connect'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearResult() {
    if (_testResult != null) setState(() => _testResult = null);
  }

  Widget _buildResultChip(BuildContext context) {
    final result = _testResult!;
    final color = result.success ? Colors.green : Colors.red;
    final icon = result.success
        ? Icons.check_circle_outline
        : Icons.error_outline;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                result.message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupTestResult {
  final bool success;
  final String message;
  const _SetupTestResult({required this.success, required this.message});
}
