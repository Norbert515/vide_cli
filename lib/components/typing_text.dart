import 'dart:async';
import 'package:nocterm/nocterm.dart';

/// A text component that animates by "typing" new text character by character
class TypingText extends StatefulComponent {
  final String text;
  final TextStyle? style;
  final Duration characterDelay;

  const TypingText({
    required this.text,
    this.style,
    this.characterDelay = const Duration(milliseconds: 30),
    super.key,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = '';
  String _previousText = '';
  Timer? _typingTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousText = component.text;
    _displayedText = component.text;
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTypingAnimation() {
    // Cancel any existing animation
    _typingTimer?.cancel();

    // Reset state
    _currentIndex = 0;
    _previousText = component.text;

    // Start with empty text (will type the new text)
    setState(() {
      _displayedText = '';
    });

    // Create timer that adds one character at a time
    _typingTimer = Timer.periodic(component.characterDelay, (timer) {
      if (_currentIndex < component.text.length) {
        setState(() {
          _displayedText = component.text.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Animation complete
        timer.cancel();
        setState(() {
          _displayedText = component.text;
        });
      }
    });
  }

  @override
  Component build(BuildContext context) {
    // Check if text changed and start animation
    if (component.text != _previousText) {
      // Use Future.microtask to avoid calling setState during build
      Future.microtask(() {
        _startTypingAnimation();
      });
    }

    return Text(_displayedText, style: component.style);
  }
}
