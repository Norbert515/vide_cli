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

class _TypingTextState extends State<TypingText>
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  String _previousText = '';
  late AnimationController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousText = component.text;
    _displayedText = component.text;

    // Initialize animation controller
    // Duration will be set dynamically based on text length
    _controller = AnimationController(
      duration: Duration(
        milliseconds:
            component.characterDelay.inMilliseconds *
            component.text.length.clamp(1, 1000),
      ),
      vsync: this,
    );
    _controller.addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    // Calculate how many characters should be shown based on animation progress
    final targetIndex = (_controller.value * component.text.length)
        .ceil()
        .clamp(0, component.text.length);

    if (targetIndex != _currentIndex) {
      setState(() {
        _currentIndex = targetIndex;
        _displayedText = component.text.substring(0, _currentIndex);
      });
    }

    // Ensure final text is fully displayed when animation completes
    if (_controller.isCompleted && _displayedText != component.text) {
      setState(() {
        _displayedText = component.text;
      });
    }
  }

  void _startTypingAnimation() {
    // Reset state
    _currentIndex = 0;
    _previousText = component.text;

    // Start with empty text (will type the new text)
    setState(() {
      _displayedText = '';
    });

    // Update duration based on new text length
    _controller.duration = Duration(
      milliseconds:
          component.characterDelay.inMilliseconds *
          component.text.length.clamp(1, 1000),
    );

    // Start the animation
    _controller.forward(from: 0);
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
