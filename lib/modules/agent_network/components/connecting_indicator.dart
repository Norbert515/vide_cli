import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// Centered loading indicator with VIDE branding, braille spinner, and label.
/// Used on the connecting/loading screen before a session is ready.
class ConnectingIndicator extends StatefulComponent {
  final String label;

  const ConnectingIndicator({required this.label, super.key});

  @override
  State<ConnectingIndicator> createState() => _ConnectingIndicatorState();
}

class _ConnectingIndicatorState extends State<ConnectingIndicator>
    with TickerProviderStateMixin {
  static const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  late AnimationController _controller;

  int get _frameIndex =>
      (_controller.value * _frames.length).floor() % _frames.length;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..addListener(() => setState(() {}))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final dim = theme.base.onSurface.withOpacity(TextOpacity.secondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'VIDE',
          style: TextStyle(
            color: theme.base.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_frames[_frameIndex], style: TextStyle(color: dim)),
            SizedBox(width: 1),
            Text(component.label, style: TextStyle(color: dim)),
          ],
        ),
      ],
    );
  }
}
