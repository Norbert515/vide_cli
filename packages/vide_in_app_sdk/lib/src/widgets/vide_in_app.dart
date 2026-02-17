import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/screenshot_service.dart';
import '../services/voice_input_service.dart';
import '../state/sdk_state.dart';
import 'chat_panel.dart';
import 'screenshot_canvas.dart';

/// Height of the collapsed bottom handle bar.
const _kHandleBarHeight = 28.0;

/// Fraction of screen height the dev tools area occupies when expanded.
const _kExpandedFraction = 0.55;

/// Padding around the user's app when the dev tools are expanded.
const _kExpandedPadding = 6.0;

/// Corner radius for the user's app when encapsulated.
const _kAppCornerRadius = 12.0;

/// Embeds your Flutter app inside the Vide dev environment.
///
/// A minimal bottom handle bar is always visible. Tapping it expands the
/// dev-tools panel (chat, screenshots) upward, shrinking the user's app.
///
/// ```dart
/// VideInApp(
///   child: MaterialApp(home: MyHomePage()),
/// )
/// ```
///
/// Programmatic control:
/// ```dart
/// VideInApp.of(context).show();   // expand
/// VideInApp.of(context).hide();   // collapse
/// VideInApp.of(context).toggle(); // toggle
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

  void show() => _state._expand();
  void hide() => _state._collapse();
  void toggle() => _state._toggle();
  Future<void> captureScreenshot() => _state._captureScreenshot();
  VideSdkState get sdkState => _state._sdkState;
}

class _VideInAppState extends State<VideInApp>
    with SingleTickerProviderStateMixin {
  late final VideSdkState _sdkState;
  late final ScreenshotService _screenshotService;
  late final VoiceInputService _voiceService;
  late final VideInAppController _controller;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _expanded = false;
  bool _screenshotMode = false;
  ui.Image? _capturedScreenshot;
  Uint8List? _pendingScreenshotBytes;

  late final AnimationController _expandController;
  late final CurvedAnimation _expandCurve;

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

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandCurve = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _sdkState.dispose();
    _voiceService.dispose();
    _capturedScreenshot?.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() => _expanded = true);
    _expandController.forward();
  }

  void _collapse() {
    _expandController.reverse().then((_) {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _toggle() {
    if (_expanded) {
      _collapse();
    } else {
      _expand();
    }
  }

  Future<void> _captureScreenshot() async {
    final wasExpanded = _expanded;
    if (wasExpanded) {
      setState(() => _expanded = false);
      _expandController.value = 0;
    }

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final image = await _screenshotService.capture();
      setState(() {
        _capturedScreenshot = image;
        _screenshotMode = true;
      });
    } catch (e) {
      if (wasExpanded && mounted) {
        _expand();
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
    _expand();
  }

  void _onScreenshotCancel() {
    _capturedScreenshot?.dispose();
    setState(() {
      _capturedScreenshot = null;
      _screenshotMode = false;
    });
    _expand();
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
    final expandedHeight = screenHeight * _kExpandedFraction;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _expandCurve,
          builder: (context, _) {
            final t = _expandCurve.value;
            final bottomHeight =
                _kHandleBarHeight + (expandedHeight - _kHandleBarHeight) * t;
            final padding = t * _kExpandedPadding;
            final radius = t * _kAppCornerRadius;

            return Container(
              color: const Color(0xFF111118),
              child: Column(
                children: [
                  // User's app
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: padding,
                        right: padding,
                        top: padding,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: RepaintBoundary(
                          key: _repaintBoundaryKey,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                  // Dev tools area (bottom)
                  SizedBox(
                    height: bottomHeight,
                    child: _OverlayMaterialShell(
                      child: Column(
                        children: [
                          _HandleBar(
                            expanded: _expanded,
                            onToggle: _toggle,
                            sdkState: _sdkState,
                          ),
                          if (t > 0)
                            Expanded(
                              child: VideChatPanel(
                                sdkState: _sdkState,
                                voiceService: _voiceService,
                                onScreenshotRequest: _captureScreenshot,
                                pendingScreenshot: _pendingScreenshotBytes,
                                onClearScreenshot: () {
                                  setState(
                                    () => _pendingScreenshotBytes = null,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Screenshot annotation canvas
        if (_screenshotMode && _capturedScreenshot != null)
          Positioned.fill(
            child: ScreenshotCanvas(
              screenshot: _capturedScreenshot!,
              onConfirm: _onScreenshotConfirm,
              onCancel: _onScreenshotCancel,
            ),
          ),
      ],
    );
  }
}

/// Bottom handle bar with Vide branding and connection status.
class _HandleBar extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VideSdkState sdkState;

  const _HandleBar({
    required this.expanded,
    required this.onToggle,
    required this.sdkState,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: SizedBox(
        height: _kHandleBarHeight,
        child: Row(
          children: [
            const SizedBox(width: 12),
            // Connection dot
            ListenableBuilder(
              listenable: sdkState,
              builder: (context, _) {
                final color = switch (sdkState.connectionState) {
                  VideSdkConnectionState.connected => const Color(0xFF4ADE80),
                  VideSdkConnectionState.connecting => const Color(0xFFFBBF24),
                  VideSdkConnectionState.error => const Color(0xFFF87171),
                  VideSdkConnectionState.disconnected => const Color(
                    0xFF6B7280,
                  ),
                };
                return Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              'vide',
              style: TextStyle(
                color: const Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.expand_less_rounded,
                color: const Color(0xFF6B7280),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// Provides Material infrastructure for widgets outside the user's MaterialApp.
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
      home: Scaffold(body: child),
    );
  }
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
