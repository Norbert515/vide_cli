import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show ProcessManager;
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/setup/theme_selector.dart';
import 'package:vide_cli/theme/theme.dart';

/// Welcome page shown on first run of Vide CLI.
/// Tests Claude Code availability and shows an animated introduction.
class WelcomePage extends StatefulComponent {
  final void Function(String? themeId) onComplete;

  const WelcomePage({required this.onComplete, super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

enum _VerificationStep {
  selectTheme,
  telemetryNotice,
  findingClaude,
  testingClaude,
  complete,
  completing,
  error,
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  _VerificationStep _step = _VerificationStep.selectTheme;
  String? _errorMessage;
  String _claudeResponse = '';
  String _displayedResponse = '';
  int _typingIndex = 0;
  late AnimationController _typingController;
  late AnimationController _shimmerController;
  int _shimmerPosition = 0;
  bool _responseComplete = false;
  bool _claudeFound = false;
  TuiThemeData? _previewTheme;
  String? _selectedThemeId;

  // Width for text wrapping (container width minus padding)
  static const int _textWidth = 52;
  static const double _boxWidth = 58;

  // ASCII art logo
  static const List<String> _logo = [
    ' ██╗   ██╗██╗██████╗ ███████╗',
    ' ██║   ██║██║██╔══██╗██╔════╝',
    ' ██║   ██║██║██║  ██║█████╗  ',
    ' ╚██╗ ██╔╝██║██║  ██║██╔══╝  ',
    '  ╚████╔╝ ██║██████╔╝███████╗',
    '   ╚═══╝  ╚═╝╚═════╝ ╚══════╝',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize typing animation controller
    _typingController = AnimationController(
      duration: const Duration(
        milliseconds: 1000,
      ), // Will be updated dynamically
      vsync: this,
    );
    _typingController.addListener(_onTypingTick);

    // Initialize shimmer animation controller (22 chars for "Confirming connection")
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2200), // 100ms per position
      vsync: this,
    );
    _shimmerController.addListener(() {
      setState(() {
        _shimmerPosition = (_shimmerController.value * 22).floor() % 22;
      });
    });
    // Start with theme selection, verification happens after
  }

  @override
  void dispose() {
    _typingController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTypingTick() {
    // Calculate how many characters should be shown based on animation progress
    final targetIndex = (_typingController.value * _claudeResponse.length)
        .ceil()
        .clamp(0, _claudeResponse.length);

    if (targetIndex != _typingIndex) {
      setState(() {
        _typingIndex = targetIndex;
        _displayedResponse = _claudeResponse.substring(0, _typingIndex);
      });
    }

    // Ensure final text is fully displayed and mark complete when animation finishes
    if (_typingController.isCompleted) {
      setState(() {
        _displayedResponse = _claudeResponse;
        _responseComplete = true;
      });
    }
  }

  Future<void> _startVerification() async {
    // Step 1: Check if Claude is available
    await Future.delayed(Duration(milliseconds: 500)); // Brief pause for effect
    final isAvailable = await ProcessManager.isClaudeAvailable();

    if (!isAvailable) {
      setState(() {
        _step = _VerificationStep.error;
        _errorMessage =
            'Claude Code not found.\n\nInstall it at:\nhttps://docs.anthropic.com/en/docs/claude-code';
      });
      return;
    }

    setState(() {
      _claudeFound = true;
      _step = _VerificationStep.testingClaude;
    });

    // Start shimmer animation for "Confirming connection"
    _startShimmerAnimation();

    // Step 2: Test Claude
    await Future.delayed(Duration(milliseconds: 300));
    await _runClaudeTest();
  }

  Future<void> _runClaudeTest() async {
    try {
      final executable = await ProcessManager.getClaudeExecutable();
      final result = await Process.run(executable, [
        '--print',
        'Respond with exactly: "Connected and ready to help!"',
      ]);

      if (result.exitCode != 0) {
        setState(() {
          _step = _VerificationStep.error;
          _errorMessage = 'Claude test failed:\n${result.stderr}';
        });
        return;
      }

      final response = (result.stdout as String).trim();
      final wrappedResponse = _wrapText(response, _textWidth);
      setState(() {
        _claudeResponse = wrappedResponse;
        _step = _VerificationStep.complete;
      });

      // Stop shimmer, start typing
      _shimmerController.stop();
      _shimmerController.reset();
      _startTypingAnimation();
    } catch (e) {
      setState(() {
        _step = _VerificationStep.error;
        _errorMessage = 'Error running Claude:\n$e';
      });
    }
  }

  void _startTypingAnimation() {
    // Reset state
    _typingIndex = 0;
    _displayedResponse = '';
    _responseComplete = false;

    // Update duration based on text length (25ms per character)
    _typingController.duration = Duration(
      milliseconds: 25 * _claudeResponse.length.clamp(1, 1000),
    );

    // Start the animation
    _typingController.forward(from: 0);
  }

  void _startShimmerAnimation() {
    _shimmerController.repeat();
  }

  void _retry() {
    _shimmerController.stop();
    _shimmerController.reset();
    _typingController.stop();
    _typingController.reset();
    setState(() {
      _step = _VerificationStep.findingClaude;
      _errorMessage = null;
      _claudeResponse = '';
      _displayedResponse = '';
      _typingIndex = 0;
      _shimmerPosition = 0;
      _responseComplete = false;
      _claudeFound = false;
      // Keep the selected theme - user already chose it
    });
    _startVerification();
  }

  String _wrapText(String text, int width) {
    final lines = <String>[];
    final paragraphs = text.split('\n');

    for (final paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        lines.add('');
        continue;
      }

      final words = paragraph.split(' ');
      var currentLine = StringBuffer();

      for (final word in words) {
        if (currentLine.isEmpty) {
          currentLine.write(word);
        } else if (currentLine.length + 1 + word.length <= width) {
          currentLine.write(' $word');
        } else {
          lines.add(currentLine.toString());
          currentLine = StringBuffer(word);
        }
      }

      if (currentLine.isNotEmpty) {
        lines.add(currentLine.toString());
      }
    }

    return lines.join('\n');
  }

  @override
  Component build(BuildContext context) {
    // Wrap in TuiTheme if we have a preview theme
    Component content = _buildMainContent(context);
    if (_previewTheme != null) {
      content = TuiTheme(
        data: _previewTheme!,
        child: VideTheme(
          data: VideThemeData.fromBrightness(_previewTheme!),
          child: content,
        ),
      );
    }
    return content;
  }

  Component _buildMainContent(BuildContext context) {
    final theme = VideTheme.of(context);

    // Show theme selector when in selectTheme step
    if (_step == _VerificationStep.selectTheme) {
      return _buildThemeSelectionView(context, theme);
    }

    // Show telemetry notice after theme selection
    if (_step == _VerificationStep.telemetryNotice) {
      return _buildTelemetryNoticeView(context, theme);
    }

    // Show loading state while completing
    if (_step == _VerificationStep.completing) {
      return Center(
        child: Text(
          'Starting Vide...',
          style: TextStyle(color: theme.base.outline),
        ),
      );
    }

    return _buildVerificationView(context, theme);
  }

  Component _buildThemeSelectionView(
    BuildContext context,
    VideThemeData theme,
  ) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: BoxBorder.all(color: theme.base.outline),
        ),
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ASCII Logo
            ..._buildLogo(theme),
            SizedBox(height: 1),

            // Tagline
            Text(
              'Your AI-powered terminal IDE',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            SizedBox(height: 2),

            // Theme selector
            ThemeSelector(
              onThemeSelected: (themeId) {
                // Save theme selection and proceed to telemetry notice
                setState(() {
                  _selectedThemeId = themeId;
                  _step = _VerificationStep.telemetryNotice;
                });
              },
              onPreviewTheme: (previewTheme) {
                setState(() {
                  _previewTheme = previewTheme;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Component _buildTelemetryNoticeView(
    BuildContext context,
    VideThemeData theme,
  ) {
    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        if (key == LogicalKey.enter) {
          setState(() {
            _step = _VerificationStep.findingClaude;
          });
          _startVerification();
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            border: BoxBorder.all(color: theme.base.outline),
          ),
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ASCII Logo
              ..._buildLogo(theme),
              SizedBox(height: 1),

              // Tagline
              Text(
                'Your AI-powered terminal IDE',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              SizedBox(height: 2),

              // Telemetry header
              Text(
                'Telemetry',
                style: TextStyle(
                  color: theme.base.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('---------', style: TextStyle(color: theme.base.outline)),
              SizedBox(height: 1),

              // Telemetry description
              Text(
                'Vide collects anonymous usage data to help',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              Text(
                'improve the tool.',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              Text(
                'No personal data, project names, or code is',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              Text(
                'ever collected.',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              SizedBox(height: 1),

              // Opt-out instructions
              Text(
                'You can opt out at any time by setting:',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              Text(
                '  export DO_NOT_TRACK=1',
                style: TextStyle(color: theme.base.warning),
              ),
              SizedBox(height: 2),

              // Footer
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Press ', style: TextStyle(color: theme.base.outline)),
                  Text('Enter', style: TextStyle(color: theme.base.success)),
                  Text(
                    ' to continue',
                    style: TextStyle(color: theme.base.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildVerificationView(BuildContext context, VideThemeData theme) {
    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        if (_step == _VerificationStep.error && key == LogicalKey.keyR) {
          _retry();
          return true;
        }
        if (_responseComplete &&
            _step == _VerificationStep.complete &&
            key == LogicalKey.enter) {
          setState(() {
            _step = _VerificationStep.completing;
          });
          component.onComplete(_selectedThemeId);
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          width: _boxWidth,
          decoration: BoxDecoration(
            border: BoxBorder.all(color: theme.base.outline),
          ),
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ASCII Logo
              ..._buildLogo(theme),
              SizedBox(height: 1),

              // Tagline
              Text(
                'Your AI-powered terminal IDE',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(
                    TextOpacity.secondary,
                  ),
                ),
              ),
              SizedBox(height: 2),

              // Verification checklist
              _buildChecklist(theme),

              // Claude response area (if complete)
              if (_step == _VerificationStep.complete) ...[
                SizedBox(height: 2),
                _buildClaudeResponse(theme),
              ],

              // Error area
              if (_step == _VerificationStep.error) ...[
                SizedBox(height: 1),
                _buildError(theme),
              ],

              SizedBox(height: 2),

              // Footer
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Component> _buildLogo(VideThemeData theme) {
    return _logo.map((line) {
      return Text(
        line,
        style: TextStyle(
          color: theme.base.primary,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  Component _buildChecklist(VideThemeData theme) {
    final isConfirmingConnection = _step == _VerificationStep.testingClaude;
    final connectionLabel = isConfirmingConnection
        ? 'Confirming connection'
        : 'Connection confirmed';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChecklistItem(
          theme,
          'Claude Code found',
          isComplete: _claudeFound,
          isActive: _step == _VerificationStep.findingClaude,
          hasError: _step == _VerificationStep.error && !_claudeFound,
        ),
        SizedBox(height: 1),
        if (isConfirmingConnection)
          _buildShimmerChecklistItem(theme, connectionLabel)
        else
          _buildChecklistItem(
            theme,
            connectionLabel,
            isComplete: _step == _VerificationStep.complete,
            isActive: false,
            hasError: _step == _VerificationStep.error && _claudeFound,
          ),
      ],
    );
  }

  Component _buildChecklistItem(
    VideThemeData theme,
    String label, {
    required bool isComplete,
    required bool isActive,
    required bool hasError,
  }) {
    String icon;
    Color iconColor;
    Color textColor;

    if (hasError) {
      icon = '✗';
      iconColor = theme.base.error;
      textColor = theme.base.error;
    } else if (isComplete) {
      icon = '✓';
      iconColor = theme.base.success;
      textColor = theme.base.onSurface;
    } else if (isActive) {
      icon = '○';
      iconColor = theme.base.warning;
      textColor = theme.base.warning;
    } else {
      icon = '○';
      iconColor = theme.base.outline;
      textColor = theme.base.outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(color: iconColor)),
        SizedBox(width: 2),
        Text(label, style: TextStyle(color: textColor)),
        if (isActive) ...[
          Text('...', style: TextStyle(color: theme.base.warning)),
        ],
      ],
    );
  }

  Component _buildShimmerChecklistItem(VideThemeData theme, String label) {
    final chars = <Component>[];

    for (int i = 0; i < label.length; i++) {
      final distFromShimmer = (i - _shimmerPosition).abs();
      Color color;

      if (distFromShimmer == 0) {
        color = theme.base.onSurface;
      } else if (distFromShimmer == 1) {
        color = theme.base.primary;
      } else if (distFromShimmer == 2) {
        color = theme.base.warning.withOpacity(0.8);
      } else {
        color = theme.base.warning.withOpacity(0.6);
      }

      chars.add(Text(label[i], style: TextStyle(color: color)));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('○', style: TextStyle(color: theme.base.warning)),
        SizedBox(width: 2),
        ...chars,
        Text('...', style: TextStyle(color: theme.base.warning)),
      ],
    );
  }

  Component _buildClaudeResponse(VideThemeData theme) {
    if (_displayedResponse.isEmpty) {
      return Text('');
    }

    return Container(
      width: (_textWidth + 4).toDouble(),
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: theme.base.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Claude',
                style: TextStyle(
                  color: theme.base.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(' says:', style: TextStyle(color: theme.base.outline)),
            ],
          ),
          SizedBox(height: 1),
          Text(
            _displayedResponse,
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Component _buildError(VideThemeData theme) {
    return Container(
      width: (_textWidth + 4).toDouble(),
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(border: BoxBorder.all(color: theme.base.error)),
      child: Text(
        _errorMessage ?? 'Unknown error',
        style: TextStyle(color: theme.base.error),
      ),
    );
  }

  Component _buildFooter(VideThemeData theme) {
    if (_step == _VerificationStep.error) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('[', style: TextStyle(color: theme.base.outline)),
          Text('R', style: TextStyle(color: theme.base.warning)),
          Text('] Retry', style: TextStyle(color: theme.base.outline)),
        ],
      );
    }

    if (_responseComplete) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Press ', style: TextStyle(color: theme.base.outline)),
          Text('Enter', style: TextStyle(color: theme.base.success)),
          Text(' to continue', style: TextStyle(color: theme.base.outline)),
        ],
      );
    }

    // Show nothing while loading
    return Text('', style: TextStyle(color: theme.base.outline));
  }
}
