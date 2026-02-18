import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vide_client/vide_client.dart';

import 'package:vide_mobile/core/theme/app_theme.dart';
import 'package:vide_mobile/core/theme/tokens.dart';
import 'package:vide_mobile/core/theme/vide_colors.dart';
import 'package:vide_mobile/features/chat/widgets/chat_helpers.dart';

import '../services/screenshot_service.dart';
import '../services/voice_input_service.dart';
import '../state/sdk_state.dart';
import 'chat_panel.dart';
import 'screenshot_canvas.dart';

/// Height of the peek bar (handle + status row).
const _kPeekHeight = 72.0;

/// Max padding around the user's app when the sheet is fully expanded.
const _kExpandedPadding = 8.0;

/// Max corner radius for the user's app when the sheet is fully expanded.
const _kAppCornerRadius = 16.0;

/// Half-screen snap fraction.
const _kHalfFraction = 0.5;

/// Full-screen snap fraction.
const _kFullFraction = 0.95;

/// Top corner radius for the sheet surface.
const _kSheetRadius = 16.0;

/// Embeds your Flutter app inside the Vide dev environment.
///
/// A compact peek bar is always visible at the bottom showing the latest
/// activity. Drag up to half screen for the full chat, or full screen for
/// maximum space. The user's app scales down smoothly as the sheet expands.
///
/// ```dart
/// VideInApp(
///   child: MaterialApp(home: MyHomePage()),
/// )
/// ```
///
/// Programmatic control:
/// ```dart
/// VideInApp.of(context).show();   // expand to half
/// VideInApp.of(context).hide();   // collapse to peek
/// VideInApp.of(context).toggle(); // toggle peek <-> half
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

  void show() => _state._animateToHalf();
  void hide() => _state._animateToPeek();
  void toggle() => _state._toggle();
  Future<void> captureScreenshot() => _state._captureScreenshot();
  VideSdkState get sdkState => _state._sdkState;
}

class _VideInAppState extends State<VideInApp> {
  late final VideSdkState _sdkState;
  late final ScreenshotService _screenshotService;
  late final VoiceInputService _voiceService;
  late final VideInAppController _controller;
  late final DraggableScrollableController _sheetController;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _screenshotMode = false;
  ui.Image? _capturedScreenshot;
  Uint8List? _pendingScreenshotBytes;

  /// Sheet size saved before entering screenshot mode, so we can restore it.
  double? _preScreenshotSize;

  /// Controls the fade animation for the screenshot overlay.
  bool _screenshotVisible = false;

  /// Cached peek fraction — computed from screen height in build.
  double _peekFraction = 0.1;

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
    _sheetController = DraggableScrollableController();

    // Auto-expand once config is loaded so the initial prompt is visible.
    _sdkState.addListener(_autoExpandOnConfigured);
  }

  void _autoExpandOnConfigured() {
    if (_sdkState.isConfigured) {
      _sdkState.removeListener(_autoExpandOnConfigured);
      // Wait for layout so _sheetController is attached
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateToHalf();
      });
    }
  }

  @override
  void dispose() {
    _sdkState.removeListener(_autoExpandOnConfigured);
    _sheetController.dispose();
    _sdkState.dispose();
    _voiceService.dispose();
    _capturedScreenshot?.dispose();
    super.dispose();
  }

  void _animateToPeek() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _peekFraction,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _animateToHalf() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _kHalfFraction,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _animateToFull() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _kFullFraction,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggle() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    if (size > _peekFraction + 0.05) {
      _animateToPeek();
    } else {
      _animateToHalf();
    }
  }

  bool get _isExpanded =>
      _sheetController.isAttached &&
      _sheetController.size > _peekFraction + 0.05;

  Future<void> _captureScreenshot() async {
    // Remember where the sheet was so we can restore after confirm/cancel.
    _preScreenshotSize =
        _sheetController.isAttached ? _sheetController.size : null;

    final wasExpanded = _isExpanded;
    if (wasExpanded) {
      _animateToPeek();
      // Wait for the collapse animation to finish before capturing.
      await Future.delayed(const Duration(milliseconds: 350));
    }

    if (!mounted) return;

    try {
      final image = await _screenshotService.capture();
      if (!mounted) return;
      // Show the overlay (opacity 0) then trigger fade-in next frame.
      setState(() {
        _capturedScreenshot = image;
        _screenshotMode = true;
        _screenshotVisible = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _screenshotVisible = true);
      });
    } catch (e) {
      if (wasExpanded && mounted) {
        _restorePreScreenshotPosition();
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

  /// Fades out the screenshot overlay, then removes it and restores the sheet.
  void _dismissScreenshotOverlay() {
    // Start the fade-out.
    setState(() => _screenshotVisible = false);

    // After the fade-out animation completes, tear down the overlay and
    // animate the sheet back to the pre-screenshot position.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _capturedScreenshot?.dispose();
      setState(() {
        _capturedScreenshot = null;
        _screenshotMode = false;
      });
      _restorePreScreenshotPosition();
    });
  }

  /// Animate back to the sheet position saved before screenshot capture.
  ///
  /// Falls back to half screen if nothing was saved (e.g. first screenshot).
  void _restorePreScreenshotPosition() {
    final target = _preScreenshotSize ?? _kHalfFraction;
    _preScreenshotSize = null;

    // Snap to the nearest detent to avoid landing between snap points.
    final double snapTarget;
    if (target <= _peekFraction + 0.05) {
      snapTarget = _kHalfFraction; // Don't restore to peek — show the input
    } else if (target < (_kHalfFraction + _kFullFraction) / 2) {
      snapTarget = _kHalfFraction;
    } else {
      snapTarget = _kFullFraction;
    }

    // Defer to next frame — the sheet may not be attached yet after setState
    // removes the screenshot overlay and re-exposes the draggable sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _sheetController.animateTo(
        snapTarget,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
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
            return _OverlayMaterialShell(
              child: _SetupScreen(sdkState: _sdkState),
            );
          }
          return _buildMainLayout(context);
        },
      ),
    );
  }

  Widget _buildMainLayout(BuildContext context) {
    final screenHeight = MediaQuery.maybeOf(context)?.size.height ?? 800;
    _peekFraction = (_kPeekHeight / screenHeight).clamp(0.05, 0.15);

    return Stack(
      children: [
        // User's app — shrinks as sheet expands
        Positioned.fill(
          child: ListenableBuilder(
            listenable: _sheetController,
            builder: (context, child) {
              final screenHeight =
                  MediaQuery.maybeOf(context)?.size.height ?? 800;
              final size = _sheetController.isAttached
                  ? _sheetController.size
                  : _peekFraction;

              // t goes from 0 (peek) to 1 (full)
              final t =
                  ((size - _peekFraction) / (_kFullFraction - _peekFraction))
                      .clamp(0.0, 1.0);

              // Side/top padding and radius scale with t
              final sidePadding = t * _kExpandedPadding;
              final radius = t * _kAppCornerRadius;

              // Bottom space = actual sheet height in pixels
              final sheetPixels = size * screenHeight;

              return Container(
                color: const Color(0xFF111118),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: sidePadding,
                    right: sidePadding,
                    top: sidePadding,
                    bottom: sheetPixels,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: child!,
                  ),
                ),
              );
            },
            child: RepaintBoundary(
              key: _repaintBoundaryKey,
              child: widget.child,
            ),
          ),
        ),

        // Draggable sheet
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _peekFraction,
          minChildSize: _peekFraction,
          maxChildSize: _kFullFraction,
          snapSizes: [_peekFraction, _kHalfFraction],
          snap: true,
          builder: (context, scrollController) {
            return _OverlayMaterialShell(
              child: _SheetContent(
                sdkState: _sdkState,
                voiceService: _voiceService,
                sheetController: _sheetController,
                scrollController: scrollController,
                peekFraction: _peekFraction,
                onScreenshotRequest: _captureScreenshot,
                pendingScreenshot: _pendingScreenshotBytes,
                onClearScreenshot: () {
                  setState(() => _pendingScreenshotBytes = null);
                },
              ),
            );
          },
        ),

        // Screenshot annotation canvas — fades in/out
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
    );
  }
}

/// Sheet content — switches between peek bar and full chat based on size.
class _SheetContent extends StatelessWidget {
  final VideSdkState sdkState;
  final VoiceInputService voiceService;
  final DraggableScrollableController sheetController;
  final ScrollController scrollController;
  final double peekFraction;
  final VoidCallback? onScreenshotRequest;
  final Uint8List? pendingScreenshot;
  final VoidCallback? onClearScreenshot;

  const _SheetContent({
    required this.sdkState,
    required this.voiceService,
    required this.sheetController,
    required this.scrollController,
    required this.peekFraction,
    this.onScreenshotRequest,
    this.pendingScreenshot,
    this.onClearScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sheetController,
      builder: (context, _) {
        final size =
            sheetController.isAttached ? sheetController.size : peekFraction;

        // t: 0 at peek, 1 when halfway to half-screen snap.
        // This gives a smooth fade zone between peek and expanded.
        final midpoint = peekFraction + (_kHalfFraction - peekFraction) * 0.5;
        final t =
            ((size - peekFraction) / (midpoint - peekFraction)).clamp(0.0, 1.0);

        // The sheet's scrollController MUST be attached to a scrollable that
        // fills the sheet. We use a CustomScrollView so the grab handle and
        // peek row are part of the same scrollable, and when at the top edge,
        // further dragging moves the sheet itself.
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            // Grab handle — always visible
            const SliverToBoxAdapter(child: _GrabHandle()),

            // Peek status — fades out as sheet expands
            SliverToBoxAdapter(
              child: Opacity(
                opacity: 1.0 - t,
                child: t < 1.0
                    ? _PeekStatusRow(sdkState: sdkState)
                    : const SizedBox.shrink(),
              ),
            ),

            // Chat content — fades in as sheet expands
            SliverFillRemaining(
              hasScrollBody: true,
              child: Opacity(
                opacity: t,
                child: t > 0.0
                    ? IgnorePointer(
                        ignoring: t < 1.0,
                        child: VideChatPanel(
                          sdkState: sdkState,
                          voiceService: voiceService,
                          onScreenshotRequest: onScreenshotRequest,
                          pendingScreenshot: pendingScreenshot,
                          onClearScreenshot: onClearScreenshot,
                        ),
                      )
                    : const SizedBox.shrink(),
                ),
            ),
          ],
        );
      },
    );
  }
}

/// Grab handle pill at the top of the sheet.
class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF6B7280),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Compact status row shown in the peek bar.
///
/// Shows connection dot + latest activity (tool name, typing, or message).
class _PeekStatusRow extends StatelessWidget {
  final VideSdkState sdkState;

  const _PeekStatusRow({required this.sdkState});

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return ListenableBuilder(
      listenable: sdkState,
      builder: (context, _) {
        final session = sdkState.session;
        final isProcessing = sdkState.videState?.isProcessing ?? false;

        // Connection dot color
        final Color dotColor;
        if (session != null) {
          dotColor = switch (sdkState.connectionState) {
            VideSdkConnectionState.connected => videColors.success,
            VideSdkConnectionState.connecting => videColors.warning,
            VideSdkConnectionState.error => videColors.error,
            VideSdkConnectionState.disconnected => videColors.textTertiary,
          };
        } else {
          final reachable = sdkState.serverReachable;
          dotColor = reachable == null
              ? videColors.warning
              : reachable
                  ? videColors.success
                  : videColors.error;
        }

        // Status text + icon
        final (String label, IconData? icon) = _resolveStatus(
          session: session,
          isProcessing: isProcessing,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.md,
            vertical: 4,
          ),
          child: Row(
            children: [
              // Connection dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Status
              if (icon != null) ...[
                Icon(icon, size: 14, color: videColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: videColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (String, IconData?) _resolveStatus({
    required RemoteVideSession? session,
    required bool isProcessing,
  }) {
    if (session == null) {
      return ('vide', null);
    }

    final mainAgent = session.state.mainAgent;
    if (mainAgent == null) {
      return ('Starting...', null);
    }

    // Get the latest visible content from the main agent's conversation
    final conversation = session.getConversation(mainAgent.id);
    final messages = conversation?.messages ?? [];

    // Always show the most recent concrete activity.
    // The icon reflects whether the agent is still working or done.
    final latestTool = _findLatestTool(messages);
    if (latestTool != null) {
      final name = toolDisplayName(latestTool.toolName);
      final subtitle = toolSubtitle(latestTool.toolName, latestTool.toolInput);
      final display = subtitle != null ? '$name  $subtitle' : name;
      final IconData icon;
      if (latestTool.result == null) {
        // Tool is in progress
        icon = Icons.play_arrow;
      } else if (latestTool.isError) {
        icon = Icons.error_outline;
      } else if (isProcessing) {
        // Tool completed but agent is still working (thinking / next step)
        icon = Icons.play_arrow;
      } else {
        icon = Icons.check;
      }
      return (display, icon);
    }

    // No tools — show last text snippet
    final lastText = _findLatestText(messages);
    if (lastText != null) {
      final firstLine = lastText.text.split('\n').first;
      return (firstLine, isProcessing ? Icons.play_arrow : null);
    }

    if (isProcessing) {
      return ('Working...', null);
    }

    return ('Ready', null);
  }

  ToolContent? _findLatestTool(List<ConversationEntry> messages) {
    for (final entry in messages.reversed) {
      for (final content in entry.content.reversed) {
        if (content is ToolContent && !isHiddenTool(content)) {
          return content;
        }
      }
    }
    return null;
  }

  TextContent? _findLatestText(List<ConversationEntry> messages) {
    for (final entry in messages.reversed) {
      if (entry.role != 'assistant') continue;
      for (final content in entry.content.reversed) {
        if (content is TextContent && content.text.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }
}

/// Provides Material infrastructure for widgets outside the user's MaterialApp.
///
/// Uses the Vide dark theme (matching vide_mobile) so that all widgets
/// inside the panel can use `Theme.of(context).extension<VideThemeColors>()!`.
class _OverlayMaterialShell extends StatelessWidget {
  final Widget child;
  const _OverlayMaterialShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(_kSheetRadius),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme(),
        // Enable mouse-drag scrolling on desktop so DraggableScrollableSheet
        // can be dragged with a mouse click on macOS/Windows/Linux.
        scrollBehavior: const _DesktopDragScrollBehavior(),
        home: Scaffold(body: child),
      ),
    );
  }
}

/// Scroll behavior that allows mouse drag to scroll on desktop platforms.
///
/// By default, Flutter only allows touch and stylus to initiate drag-scroll.
/// This adds [PointerDeviceKind.mouse] so that click-and-drag on macOS /
/// Windows / Linux drives the [DraggableScrollableSheet].
class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.mouse,
      };
}

/// Full-screen setup page shown before the server is configured.
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
