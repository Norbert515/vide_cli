import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart' show ProcessManager;
import 'package:vide_cli/components/vortex_background.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/setup/theme_selector.dart';
import 'package:vide_cli/theme/theme.dart';

/// Welcome page shown on first run of Vide CLI.
///
/// Wizard-style onboarding with a horizontal step indicator and bordered cards,
/// rendered over an animated vortex background.
class WelcomePage extends StatefulComponent {
  final void Function(String? themeId) onComplete;

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

enum _WizardStep { theme, privacy, agents }

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
  _WizardStep _currentStep = _WizardStep.theme;
  final Set<_WizardStep> _completedSteps = {};

  // Theme
  TuiThemeData? _previewTheme;
  String? _selectedThemeId;

  // Agent detection
  _AgentStatus _claudeStatus = _AgentStatus.pending;
  String? _claudePath;
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

  static const int _cardWidth = 82;
  static const int _contentWidth =
      74; // card width minus padding (3*2 + border 2)
  static const int _contentHeight =
      17; // fixed height for step content area (tallest step: theme)

  static const List<String> _logo = [
    ' ██╗   ██╗██╗██████╗ ███████╗',
    ' ██║   ██║██║██╔══██╗██╔════╝',
    ' ██║   ██║██║██║  ██║█████╗  ',
    ' ╚██╗ ██╔╝██║██║  ██║██╔══╝  ',
    '  ╚████╔╝ ██║██████╔╝███████╗',
    '   ╚═══╝  ╚═╝╚═════╝ ╚══════╝',
  ];

  static const _steps = [
    (step: _WizardStep.theme, label: 'Theme', number: 1),
    (step: _WizardStep.privacy, label: 'Privacy', number: 2),
    (step: _WizardStep.agents, label: 'Agents', number: 3),
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
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  void _goToStep(_WizardStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _onThemeSelected(String? themeId) {
    setState(() {
      _selectedThemeId = themeId;
      _completedSteps.add(_WizardStep.theme);
    });
    _goToStep(_WizardStep.privacy);
  }

  void _onPrivacyContinue() {
    setState(() {
      _completedSteps.add(_WizardStep.privacy);
    });
    _goToStep(_WizardStep.agents);
    _startAgentDetection();
  }

  Future<void> _startAgentDetection() async {
    setState(() {
      _claudeStatus = _AgentStatus.scanning;
      _claudePath = null;
      _errorMessage = null;
    });
    _spinnerController.repeat();

    if (component.mockMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() {
        _claudeStatus = _AgentStatus.found;
        _claudePath = '/usr/local/bin/claude';
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
        _completedSteps.add(_WizardStep.agents);
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

    // Get the executable path for display
    try {
      _claudePath = await ProcessManager.getClaudeExecutable();
    } catch (_) {
      // Path display is optional
    }
    if (!mounted) return;

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
        _completedSteps.add(_WizardStep.agents);
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
      _claudePath = null;
      _errorMessage = null;
      _completedSteps.remove(_WizardStep.agents);
      _currentStep = _WizardStep.agents;
    });
    _startAgentDetection();
  }

  @override
  Component build(BuildContext context) {
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
    // Read theme inside a Builder so the preview theme override (applied
    // by build() above) is visible. Previously the theme was captured from
    // the outer context before the override was injected.
    return Builder(
      builder: (innerContext) {
        final theme = VideTheme.of(innerContext);

        if (_completing) {
          return Center(
            child: Text(
              'Starting Vide...',
              style: TextStyle(color: theme.base.outline),
            ),
          );
        }

        return VortexBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight.toInt();
              return Center(child: _buildCard(theme, availableHeight));
            },
          ),
        );
      },
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

  // ── Step Indicator ──────────────────────────────────────────────────

  Component _buildStepIndicator(VideThemeData theme) {
    final items = <Component>[];

    for (int i = 0; i < _steps.length; i++) {
      final entry = _steps[i];
      final isCompleted = _completedSteps.contains(entry.step);
      final isActive = _currentStep == entry.step;

      // Icon
      String icon;
      Color iconColor;
      Color labelColor;
      FontWeight labelWeight;

      if (isCompleted) {
        icon = '✓';
        iconColor = theme.base.success;
        labelColor = theme.base.onSurface;
        labelWeight = FontWeight.normal;
      } else if (isActive) {
        icon = '●';
        iconColor = theme.base.primary;
        labelColor = theme.base.primary;
        labelWeight = FontWeight.bold;
      } else {
        icon = '○';
        iconColor = theme.base.outline;
        labelColor = theme.base.outline;
        labelWeight = FontWeight.normal;
      }

      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(color: iconColor)),
            SizedBox(width: 1),
            Text(
              entry.label,
              style: TextStyle(color: labelColor, fontWeight: labelWeight),
            ),
          ],
        ),
      );

      // Connector between steps
      if (i < _steps.length - 1) {
        items.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: Text('───', style: TextStyle(color: theme.base.outline)),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }

  // ── Card ────────────────────────────────────────────────────────────

  Component _buildCard(VideThemeData theme, int availableHeight) {
    Component stepContent;
    switch (_currentStep) {
      case _WizardStep.theme:
        stepContent = _buildThemeStep(theme);
      case _WizardStep.privacy:
        stepContent = _buildPrivacyStep(theme);
      case _WizardStep.agents:
        stepContent = _buildAgentsStep(theme);
    }

    // Adapt header based on available terminal height:
    // >= 30: full ASCII art logo (6 lines)
    // >= 22: compact "VIDE" text (1 line)
    // < 22: no logo, just step indicator
    final showFullLogo = availableHeight >= 30;
    final showCompactLogo = !showFullLogo && availableHeight >= 22;

    return Container(
      width: _cardWidth.toDouble(),
      decoration: BoxDecoration(
        color: theme.base.surface,
        border: BoxBorder.all(color: theme.base.outline),
      ),
      padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
            SizedBox(height: 1),
          ] else if (showCompactLogo) ...[
            Text(
              'VIDE',
              style: TextStyle(
                color: theme.base.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 1),
          ],

          // Step indicator
          _buildStepIndicator(theme),
          SizedBox(height: 1),

          // Divider between header and step content
          _buildDivider(theme),
          SizedBox(height: 1),

          // Step content — fixed height so card doesn't resize between steps
          SizedBox(height: _contentHeight.toDouble(), child: stepContent),
        ],
      ),
    );
  }

  Component _buildDivider(VideThemeData theme) {
    return Text(
      '─' * (_contentWidth),
      style: TextStyle(
        color: theme.base.outline.withOpacity(TextOpacity.separator),
      ),
    );
  }

  // ── Step 1: Theme ───────────────────────────────────────────────────

  Component _buildThemeStep(VideThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your theme',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
        SizedBox(height: 1),
        ThemeSelector(
          initialThemeId: _selectedThemeId,
          onThemeSelected: _onThemeSelected,
          onPreviewTheme: (previewTheme) {
            setState(() {
              _previewTheme = previewTheme;
            });
          },
        ),
      ],
    );
  }

  // ── Step 2: Privacy ─────────────────────────────────────────────────

  Component _buildPrivacyStep(VideThemeData theme) {
    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        if (key == LogicalKey.enter) {
          _onPrivacyContinue();
          return true;
        }
        return false;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vide collects anonymous usage data to help improve',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          Text(
            'the tool. No personal data, project names, or code',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          Text(
            'is ever collected.',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Opt out: ',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
              Text(
                'export DO_NOT_TRACK=1',
                style: TextStyle(color: theme.base.warning),
              ),
            ],
          ),
          SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Press ', style: TextStyle(color: theme.base.outline)),
              Text('Enter', style: TextStyle(color: theme.base.success)),
              Text(' to continue', style: TextStyle(color: theme.base.outline)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: Agents ────────────────────────────────────────────────

  Component _buildAgentsStep(VideThemeData theme) {
    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        if (_claudeStatus == _AgentStatus.verified && key == LogicalKey.enter) {
          setState(() {
            _completing = true;
          });
          component.onComplete(_selectedThemeId);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detecting installed coding agents',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
            ),
          ),
          SizedBox(height: 1),

          // Claude Code - actively detected
          _buildAgentRow(theme, 'Claude Code', _claudeStatus, _claudePath),

          // Future agents - not installed
          _buildUnavailableAgent(theme, 'Gemini CLI', 'Coming soon'),
          _buildUnavailableAgent(theme, 'GitHub Copilot', 'Coming soon'),
          _buildUnavailableAgent(theme, 'Codex CLI', 'Coming soon'),

          // Error display
          if (_claudeStatus == _AgentStatus.error ||
              _claudeStatus == _AgentStatus.notFound) ...[
            SizedBox(height: 1),
            if (_errorMessage != null)
              Text(_errorMessage!, style: TextStyle(color: theme.base.error)),
            SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('[', style: TextStyle(color: theme.base.outline)),
                Text('R', style: TextStyle(color: theme.base.warning)),
                Text('] Retry', style: TextStyle(color: theme.base.outline)),
              ],
            ),
          ],

          // Continue prompt after verification
          if (_claudeStatus == _AgentStatus.verified) ...[
            SizedBox(height: 1),
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
        ],
      ),
    );
  }

  Component _buildAgentRow(
    VideThemeData theme,
    String name,
    _AgentStatus status,
    String? path,
  ) {
    final spinner = _brailleFrames[_spinnerFrame];
    final isLoading =
        status == _AgentStatus.scanning || status == _AgentStatus.verifying;

    // Icon
    String icon;
    Color iconColor;
    if (status == _AgentStatus.verified) {
      icon = '✓';
      iconColor = theme.base.success;
    } else if (status == _AgentStatus.error ||
        status == _AgentStatus.notFound) {
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
    switch (status) {
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
        statusText = 'Verified';
        statusColor = theme.base.success;
      case _AgentStatus.notFound:
        statusText = 'Not found';
        statusColor = theme.base.error;
      case _AgentStatus.error:
        statusText = 'Error';
        statusColor = theme.base.error;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(color: iconColor)),
            SizedBox(width: 2),
            Text(
              name,
              style: TextStyle(
                color: status == _AgentStatus.verified
                    ? theme.base.onSurface
                    : isLoading
                    ? theme.base.onSurface
                    : theme.base.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 2),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
        if (path != null &&
            (status == _AgentStatus.found ||
                status == _AgentStatus.verifying ||
                status == _AgentStatus.verified))
          Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              path,
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ),
      ],
    );
  }

  Component _buildUnavailableAgent(
    VideThemeData theme,
    String name,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '○',
          style: TextStyle(
            color: theme.base.outline.withOpacity(TextOpacity.disabled),
          ),
        ),
        SizedBox(width: 2),
        Text(
          name,
          style: TextStyle(
            color: theme.base.outline.withOpacity(TextOpacity.disabled),
          ),
        ),
        SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: theme.base.outline.withOpacity(TextOpacity.disabled),
          ),
        ),
      ],
    );
  }
}
