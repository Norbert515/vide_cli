import 'dart:async';
import 'dart:io';
import 'package:claude_api/claude_api.dart';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// Welcome page shown on first run of Vide CLI.
/// Tests Claude Code availability and shows an animated introduction.
class WelcomePage extends StatefulComponent {
  final VoidCallback onComplete;

  const WelcomePage({required this.onComplete, super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

enum _VerificationStep { findingClaude, testingClaude, complete, error }

class _WelcomePageState extends State<WelcomePage> {
  _VerificationStep _step = _VerificationStep.findingClaude;
  String? _errorMessage;
  String _claudeResponse = '';
  String _displayedResponse = '';
  int _typingIndex = 0;
  Timer? _typingTimer;
  Timer? _shimmerTimer;
  int _shimmerPosition = 0;
  bool _responseComplete = false;
  bool _claudeFound = false;

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
    _startVerification();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _shimmerTimer?.cancel();
    super.dispose();
  }

  Future<void> _startVerification() async {
    // Step 1: Check if Claude is available
    await Future.delayed(Duration(milliseconds: 500)); // Brief pause for effect
    final isAvailable = await ProcessManager.isClaudeAvailable();

    if (!isAvailable) {
      setState(() {
        _step = _VerificationStep.error;
        _errorMessage = 'Claude Code not found.\n\nInstall it at:\nhttps://docs.anthropic.com/en/docs/claude-code';
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
      final result = await Process.run(
        'claude',
        ['--print', 'Respond with exactly: "Connected and ready to help!"'],
      );

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
      _shimmerTimer?.cancel();
      _startTypingAnimation();
    } catch (e) {
      setState(() {
        _step = _VerificationStep.error;
        _errorMessage = 'Error running Claude:\n$e';
      });
    }
  }

  void _startTypingAnimation() {
    _typingTimer = Timer.periodic(Duration(milliseconds: 25), (timer) {
      if (_typingIndex < _claudeResponse.length) {
        setState(() {
          _typingIndex++;
          _displayedResponse = _claudeResponse.substring(0, _typingIndex);
        });
      } else {
        timer.cancel();
        setState(() {
          _responseComplete = true;
        });
      }
    });
  }

  void _startShimmerAnimation() {
    _shimmerTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        _shimmerPosition = (_shimmerPosition + 1) % 22; // Length of "Confirming connection"
      });
    });
  }

  void _retry() {
    _shimmerTimer?.cancel();
    setState(() {
      _step = _VerificationStep.findingClaude;
      _errorMessage = null;
      _claudeResponse = '';
      _displayedResponse = '';
      _typingIndex = 0;
      _shimmerPosition = 0;
      _responseComplete = false;
      _claudeFound = false;
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
    return KeyboardListener(
      autofocus: true,
      onKeyEvent: (key) {
        if (_step == _VerificationStep.error && key == LogicalKey.keyR) {
          _retry();
          return true;
        }
        if (_responseComplete && key == LogicalKey.enter) {
          component.onComplete();
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          width: _boxWidth,
          decoration: BoxDecoration(
            border: BoxBorder.all(color: Colors.grey),
          ),
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ASCII Logo
              ..._buildLogo(),
              SizedBox(height: 1),

              // Tagline
              Text(
                'Your AI-powered terminal IDE',
                style: TextStyle(
                  color: Colors.white.withOpacity(TextOpacity.secondary),
                ),
              ),
              SizedBox(height: 2),

              // Verification checklist
              _buildChecklist(),

              // Claude response area (if complete)
              if (_step == _VerificationStep.complete) ...[
                SizedBox(height: 2),
                _buildClaudeResponse(),
              ],

              // Error area
              if (_step == _VerificationStep.error) ...[
                SizedBox(height: 1),
                _buildError(),
              ],

              SizedBox(height: 2),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  List<Component> _buildLogo() {
    return _logo.map((line) {
      return Text(
        line,
        style: TextStyle(
          color: Colors.cyan,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  Component _buildChecklist() {
    final isConfirmingConnection = _step == _VerificationStep.testingClaude;
    final connectionLabel = isConfirmingConnection ? 'Confirming connection' : 'Connection confirmed';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChecklistItem(
          'Claude Code found',
          isComplete: _claudeFound,
          isActive: _step == _VerificationStep.findingClaude,
          hasError: _step == _VerificationStep.error && !_claudeFound,
        ),
        SizedBox(height: 1),
        if (isConfirmingConnection)
          _buildShimmerChecklistItem(connectionLabel)
        else
          _buildChecklistItem(
            connectionLabel,
            isComplete: _step == _VerificationStep.complete,
            isActive: false,
            hasError: _step == _VerificationStep.error && _claudeFound,
          ),
      ],
    );
  }

  Component _buildChecklistItem(
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
      iconColor = Colors.red;
      textColor = Colors.red;
    } else if (isComplete) {
      icon = '✓';
      iconColor = Colors.green;
      textColor = Colors.white;
    } else if (isActive) {
      icon = '○';
      iconColor = Colors.yellow;
      textColor = Colors.yellow;
    } else {
      icon = '○';
      iconColor = Colors.grey;
      textColor = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(color: iconColor)),
        SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(color: textColor),
        ),
        if (isActive) ...[
          Text('...', style: TextStyle(color: Colors.yellow)),
        ],
      ],
    );
  }

  Component _buildShimmerChecklistItem(String label) {
    final chars = <Component>[];

    for (int i = 0; i < label.length; i++) {
      final distFromShimmer = (i - _shimmerPosition).abs();
      Color color;

      if (distFromShimmer == 0) {
        color = Colors.white;
      } else if (distFromShimmer == 1) {
        color = Colors.cyan;
      } else if (distFromShimmer == 2) {
        color = Colors.yellow.withOpacity(0.8);
      } else {
        color = Colors.yellow.withOpacity(0.6);
      }

      chars.add(Text(label[i], style: TextStyle(color: color)));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('○', style: TextStyle(color: Colors.yellow)),
        SizedBox(width: 2),
        ...chars,
        Text('...', style: TextStyle(color: Colors.yellow)),
      ],
    );
  }

  Component _buildClaudeResponse() {
    if (_displayedResponse.isEmpty) {
      return Text('');
    }

    return Container(
      width: (_textWidth + 4).toDouble(),
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.grey),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Claude', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
              Text(' says:', style: TextStyle(color: Colors.grey)),
            ],
          ),
          SizedBox(height: 1),
          Text(
            _displayedResponse,
            style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
          ),
        ],
      ),
    );
  }

  Component _buildError() {
    return Container(
      width: (_textWidth + 4).toDouble(),
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.red),
      ),
      child: Text(
        _errorMessage ?? 'Unknown error',
        style: TextStyle(color: Colors.red),
      ),
    );
  }

  Component _buildFooter() {
    if (_step == _VerificationStep.error) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('[', style: TextStyle(color: Colors.grey)),
          Text('R', style: TextStyle(color: Colors.yellow)),
          Text('] Retry', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (_responseComplete) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Press ', style: TextStyle(color: Colors.grey)),
          Text('Enter', style: TextStyle(color: Colors.green)),
          Text(' to continue', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    // Show nothing while loading
    return Text('', style: TextStyle(color: Colors.grey));
  }
}
