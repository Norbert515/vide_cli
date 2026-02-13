import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/screenshot_service.dart';
import '../services/voice_input_service.dart';
import '../state/sdk_state.dart';
import 'chat_panel.dart';
import 'screenshot_canvas.dart';

/// Trigger mechanism for opening the Vide overlay.
enum VideTrigger {
  /// Floating action button (always visible).
  fab,

  /// Device shake gesture (mobile only).
  shake,

  /// Both FAB and shake.
  both,

  /// Manual only — use [VideInApp.of(context).show()].
  manual,
}

/// Adds the Vide AI assistant overlay to your Flutter app.
///
/// Wrap your [MaterialApp] (or [CupertinoApp]) with this widget:
///
/// ```dart
/// VideInApp(
///   child: MaterialApp(
///     home: MyHomePage(),
///   ),
/// )
/// ```
///
/// Server URL and working directory are configured in-app and persisted.
/// Access the controller from anywhere:
/// ```dart
/// VideInApp.of(context).show();
/// ```
class VideInApp extends StatefulWidget {
  /// How to trigger the overlay.
  final VideTrigger trigger;

  /// Your app widget (typically a MaterialApp).
  final Widget child;

  const VideInApp({
    super.key,
    this.trigger = VideTrigger.fab,
    required this.child,
  });

  /// Access the Vide controller from anywhere in the widget tree.
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

/// Controller for programmatic access to the Vide overlay.
class VideInAppController {
  final _VideInAppState _state;

  VideInAppController._(this._state);

  /// Show the chat panel.
  void show() => _state._showPanel();

  /// Hide the chat panel.
  void hide() => _state._hidePanel();

  /// Toggle the chat panel.
  void toggle() => _state._togglePanel();

  /// Take a screenshot and open the annotation canvas.
  Future<void> captureScreenshot() => _state._captureScreenshot();

  /// Get the SDK state for direct access.
  VideSdkState get sdkState => _state._sdkState;
}

class _VideInAppState extends State<VideInApp>
    with SingleTickerProviderStateMixin {
  late final VideSdkState _sdkState;
  late final ScreenshotService _screenshotService;
  late final VoiceInputService _voiceService;
  late final VideInAppController _controller;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _panelVisible = false;
  bool _screenshotMode = false;
  ui.Image? _capturedScreenshot;
  Uint8List? _pendingScreenshotBytes;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

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

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _sdkState.dispose();
    _voiceService.dispose();
    _capturedScreenshot?.dispose();
    super.dispose();
  }

  void _showPanel() {
    setState(() => _panelVisible = true);
    _slideController.forward();
  }

  void _hidePanel() {
    _slideController.reverse().then((_) {
      if (mounted) setState(() => _panelVisible = false);
    });
  }

  void _togglePanel() {
    if (_panelVisible) {
      _hidePanel();
    } else {
      _showPanel();
    }
  }

  Future<void> _captureScreenshot() async {
    final wasVisible = _panelVisible;
    if (wasVisible) {
      setState(() => _panelVisible = false);
      _slideController.value = 0;
    }

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final image = await _screenshotService.capture();
      setState(() {
        _capturedScreenshot = image;
        _screenshotMode = true;
      });
    } catch (e) {
      if (wasVisible && mounted) {
        _showPanel();
      }
    }
  }

  void _onScreenshotConfirm(Uint8List bytes) {
    _capturedScreenshot?.dispose();
    setState(() {
      _capturedScreenshot = null;
      _screenshotMode = false;
      _pendingScreenshotBytes = bytes;
    });
    _showPanel();
  }

  void _onScreenshotCancel() {
    _capturedScreenshot?.dispose();
    setState(() {
      _capturedScreenshot = null;
      _screenshotMode = false;
    });
    _showPanel();
  }

  @override
  Widget build(BuildContext context) {
    final showFab =
        (widget.trigger == VideTrigger.fab ||
            widget.trigger == VideTrigger.both) &&
        !_screenshotMode;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // The user's app, wrapped in a repaint boundary for screenshots
          RepaintBoundary(key: _repaintBoundaryKey, child: widget.child),

          // Screenshot annotation canvas (full screen)
          if (_screenshotMode && _capturedScreenshot != null)
            Positioned.fill(
              child: ScreenshotCanvas(
                screenshot: _capturedScreenshot!,
                onConfirm: _onScreenshotConfirm,
                onCancel: _onScreenshotCancel,
              ),
            ),

          // Scrim behind the panel
          if (_panelVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _hidePanel,
                child: AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, _) {
                    return ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 0.4 * _slideController.value,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Chat panel (slides up from bottom)
          if (_panelVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: (MediaQuery.maybeOf(context)?.size.height ?? 600) * 0.75,
              child: SlideTransition(
                position: _slideAnimation,
                child: _OverlayMaterialShell(
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
              ),
            ),

          // Floating action button
          if (showFab && !_panelVisible)
            Positioned(
              right: 16,
              bottom: (MediaQuery.maybeOf(context)?.padding.bottom ?? 0) + 16,
              child: _VideFab(onTap: _togglePanel),
            ),
        ],
      ),
    );
  }
}

/// Provides the full Material infrastructure (Theme, Localizations, Navigator,
/// Overlay) for widgets that sit outside the user's MaterialApp.
class _OverlayMaterialShell extends StatelessWidget {
  final Widget child;
  const _OverlayMaterialShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: child,
    );
  }
}

/// The floating action button that triggers the overlay.
class _VideFab extends StatefulWidget {
  final VoidCallback onTap;

  const _VideFab({required this.onTap});

  @override
  State<_VideFab> createState() => _VideFabState();
}

class _VideFabState extends State<_VideFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + 0.05 * _pulseController.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
