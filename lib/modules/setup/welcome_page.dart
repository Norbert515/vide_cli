import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show ProcessManager;
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// Welcome page shown on first run of Vide CLI.
///
/// Single-screen onboarding that auto-detects Claude Code and shows a
/// privacy notice. Theme is auto-detected from the terminal.
class WelcomePage extends StatefulComponent {
  final VoidCallback onComplete;

  /// If true, skip Claude verification (use mock response).
  final bool mockMode;

  const WelcomePage({
    required this.onComplete,
    this.mockMode = false,
    super.key,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

enum _AgentStatus {
  pending,
  scanning,
  found,
  verifying,
  verified,
  notFound,
  error,
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  // Agent detection
  _AgentStatus _claudeStatus = _AgentStatus.pending;
  String? _errorMessage;

  // Braille spinner
  late AnimationController _spinnerController;
  int _spinnerFrame = 0;
  static const _brailleFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  // Completing
  bool _completing = false;

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

    _spinnerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _spinnerController.addListener(() {
      setState(() {
        _spinnerFrame =
            (_spinnerController.value * _brailleFrames.length).floor() %
            _brailleFrames.length;
      });
    });

    _startAgentDetection();
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  Future<void> _startAgentDetection() async {
    setState(() {
      _claudeStatus = _AgentStatus.scanning;
      _errorMessage = null;
    });
    _spinnerController.repeat();

    if (component.mockMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() {
        _claudeStatus = _AgentStatus.found;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _claudeStatus = _AgentStatus.verifying;
      });
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      _spinnerController.stop();
      _spinnerController.reset();
      setState(() {
        _claudeStatus = _AgentStatus.verified;
      });
      return;
    }

    // Real detection
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final isAvailable = await ProcessManager.isClaudeAvailable();
    if (!mounted) return;

    if (!isAvailable) {
      _spinnerController.stop();
      _spinnerController.reset();
      setState(() {
        _claudeStatus = _AgentStatus.notFound;
        _errorMessage =
            'Claude Code not found.\n\nInstall it at:\nhttps://docs.anthropic.com/en/docs/claude-code';
      });
      return;
    }

    setState(() {
      _claudeStatus = _AgentStatus.found;
    });

    setState(() {
      _claudeStatus = _AgentStatus.verifying;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _verifyClaudeAgent();
  }

  Future<void> _verifyClaudeAgent() async {
    try {
      final executable = await ProcessManager.getClaudeExecutable();
      final result = await Process.run(executable, [
        '--print',
        'Respond with exactly one word: "ok"',
      ]);
      if (!mounted) return;

      if (result.exitCode != 0) {
        _spinnerController.stop();
        _spinnerController.reset();
        setState(() {
          _claudeStatus = _AgentStatus.error;
          _errorMessage = 'Claude test failed:\n${result.stderr}';
        });
        return;
      }

      _spinnerController.stop();
      _spinnerController.reset();
      setState(() {
        _claudeStatus = _AgentStatus.verified;
      });
    } catch (e) {
      if (!mounted) return;
      _spinnerController.stop();
      _spinnerController.reset();
      setState(() {
        _claudeStatus = _AgentStatus.error;
        _errorMessage = 'Error running Claude:\n$e';
      });
    }
  }

  void _retry() {
    _spinnerController.stop();
    _spinnerController.reset();
    setState(() {
      _claudeStatus = _AgentStatus.pending;
      _errorMessage = null;
    });
    _startAgentDetection();
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    if (_completing) {
      return Center(
        child: Text(
          'Starting Vide...',
          style: TextStyle(color: theme.base.outline),
        ),
      );
    }

    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        if (_claudeStatus == _AgentStatus.verified && key == LogicalKey.enter) {
          setState(() {
            _completing = true;
          });
          component.onComplete();
          return true;
        }
        if ((_claudeStatus == _AgentStatus.error ||
                _claudeStatus == _AgentStatus.notFound) &&
            key == LogicalKey.keyR) {
          _retry();
          return true;
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.toInt();
          final showFullLogo = availableHeight >= 24;
          final showCompactLogo = !showFullLogo && availableHeight >= 16;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo — adaptive
                if (showFullLogo) ...[
                  ..._buildLogo(theme),
                  SizedBox(height: 1),
                  Text(
                    'Your AI-powered terminal IDE',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.tertiary,
                      ),
                    ),
                  ),
                ] else if (showCompactLogo) ...[
                  Text(
                    'VIDE',
                    style: TextStyle(
                      color: theme.base.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

                SizedBox(height: 2),

                // Agent detection — single line
                _buildAgentRow(theme),

                // Error display
                if (_claudeStatus == _AgentStatus.error ||
                    _claudeStatus == _AgentStatus.notFound) ...[
                  SizedBox(height: 1),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.base.error),
                    ),
                  SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('[', style: TextStyle(color: theme.base.outline)),
                      Text('R', style: TextStyle(color: theme.base.warning)),
                      Text(
                        '] Retry',
                        style: TextStyle(color: theme.base.outline),
                      ),
                    ],
                  ),
                ],

                // Continue prompt after verification
                if (_claudeStatus == _AgentStatus.verified) ...[
                  SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Press ',
                        style: TextStyle(color: theme.base.outline),
                      ),
                      Text(
                        'Enter',
                        style: TextStyle(color: theme.base.success),
                      ),
                      Text(
                        ' to get started',
                        style: TextStyle(color: theme.base.outline),
                      ),
                    ],
                  ),
                ],

                // Privacy footnote
                SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Anonymous usage data · ',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                    Text(
                      'Opt out: ',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                    Text(
                      'export DO_NOT_TRACK=1',
                      style: TextStyle(
                        color: theme.base.warning.withOpacity(
                          TextOpacity.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Component> _buildLogo(VideThemeData theme) {
    return _logo
        .map(
          (line) => Text(
            line,
            style: TextStyle(
              color: theme.base.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
        .toList();
  }

  Component _buildAgentRow(VideThemeData theme) {
    final spinner = _brailleFrames[_spinnerFrame];
    final isLoading =
        _claudeStatus == _AgentStatus.scanning ||
        _claudeStatus == _AgentStatus.verifying;

    // Icon
    String icon;
    Color iconColor;
    if (_claudeStatus == _AgentStatus.verified) {
      icon = '✓';
      iconColor = theme.base.success;
    } else if (_claudeStatus == _AgentStatus.error ||
        _claudeStatus == _AgentStatus.notFound) {
      icon = '✗';
      iconColor = theme.base.error;
    } else if (isLoading) {
      icon = spinner;
      iconColor = theme.base.warning;
    } else {
      icon = '○';
      iconColor = theme.base.outline;
    }

    // Status text
    String statusText;
    Color statusColor;
    switch (_claudeStatus) {
      case _AgentStatus.pending:
        statusText = '';
        statusColor = theme.base.outline;
      case _AgentStatus.scanning:
        statusText = 'Scanning...';
        statusColor = theme.base.warning;
      case _AgentStatus.found:
        statusText = 'Found';
        statusColor = theme.base.success;
      case _AgentStatus.verifying:
        statusText = 'Verifying...';
        statusColor = theme.base.warning;
      case _AgentStatus.verified:
        statusText = 'Ready';
        statusColor = theme.base.success;
      case _AgentStatus.notFound:
        statusText = 'Not found';
        statusColor = theme.base.error;
      case _AgentStatus.error:
        statusText = 'Error';
        statusColor = theme.base.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(color: iconColor)),
        SizedBox(width: 1),
        Text(
          'Claude Code',
          style: TextStyle(
            color: isLoading || _claudeStatus == _AgentStatus.verified
                ? theme.base.onSurface
                : theme.base.outline,
          ),
        ),
        SizedBox(width: 1),
        Text(statusText, style: TextStyle(color: statusColor)),
      ],
    );
  }
}
