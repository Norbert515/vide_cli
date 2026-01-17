import 'dart:math' as math;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// A widget that applies an animated shimmer effect to its child.
///
/// The shimmer creates a diagonal highlight that sweeps across the child
/// periodically, creating a subtle glowing effect.
///
/// Example:
/// ```dart
/// Shimmer(
///   child: AsciiText('VIDE', style: TextStyle(color: Colors.blue)),
/// )
/// ```
class Shimmer extends StatefulComponent {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    this.delay = const Duration(seconds: 3),
    this.angle = 0.5,
    this.highlightWidth = 3,
  });

  /// The child widget to apply the shimmer effect to.
  final Component child;

  /// The base color of the shimmer. If null, preserves the child's colors.
  final Color? baseColor;

  /// The highlight color at the peak of the shimmer.
  /// If null, uses white with varying opacity.
  final Color? highlightColor;

  /// Duration of a single shimmer sweep.
  final Duration duration;

  /// Delay between shimmer animations.
  final Duration delay;

  /// Angle of the shimmer line (0 = horizontal, 1 = 45 degrees).
  /// Values between 0 and 1 create angled lines.
  final double angle;

  /// Width of the highlight in characters.
  final int highlightWidth;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: component.duration,
      vsync: this,
    );

    // Use ease-in curve for the animation
    _animation = CurveTween(curve: Curves.easeIn).animate(_controller);

    _controller.addListener(() => setState(() {}));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimating = false;
        _scheduleNextShimmer();
      }
    });

    _scheduleNextShimmer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleNextShimmer() {
    // Use Future.delayed for the delay between shimmer animations
    Future.delayed(component.delay, () {
      if (mounted) {
        _startShimmer();
      }
    });
  }

  void _startShimmer() {
    _isAnimating = true;
    _controller.forward(from: 0);
  }

  @override
  Component build(BuildContext context) {
    return _ShimmerRenderWidget(
      progress: _isAnimating ? _animation.value : -1,
      baseColor: component.baseColor,
      highlightColor: component.highlightColor,
      angle: component.angle,
      highlightWidth: component.highlightWidth,
      child: component.child,
    );
  }
}

class _ShimmerRenderWidget extends SingleChildRenderObjectComponent {
  const _ShimmerRenderWidget({
    required this.progress,
    this.baseColor,
    this.highlightColor,
    required this.angle,
    required this.highlightWidth,
    required Component child,
  }) : super(child: child);

  final double progress;
  final Color? baseColor;
  final Color? highlightColor;
  final double angle;
  final int highlightWidth;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderShimmer(
      progress: progress,
      baseColor: baseColor,
      highlightColor: highlightColor,
      angle: angle,
      highlightWidth: highlightWidth,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderShimmer renderObject) {
    renderObject
      ..progress = progress
      ..baseColor = baseColor
      ..highlightColor = highlightColor
      ..angle = angle
      ..highlightWidth = highlightWidth;
  }
}

class _RenderShimmer extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  _RenderShimmer({
    required double progress,
    Color? baseColor,
    Color? highlightColor,
    required double angle,
    required int highlightWidth,
  }) : _progress = progress,
       _baseColor = baseColor,
       _highlightColor = highlightColor,
       _angle = angle,
       _highlightWidth = highlightWidth;

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  Color? _baseColor;
  Color? get baseColor => _baseColor;
  set baseColor(Color? value) {
    if (_baseColor == value) return;
    _baseColor = value;
    markNeedsPaint();
  }

  Color? _highlightColor;
  Color? get highlightColor => _highlightColor;
  set highlightColor(Color? value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    markNeedsPaint();
  }

  double _angle;
  double get angle => _angle;
  set angle(double value) {
    if (_angle == value) return;
    _angle = value;
    markNeedsPaint();
  }

  int _highlightWidth;
  int get highlightWidth => _highlightWidth;
  set highlightWidth(int value) {
    if (_highlightWidth == value) return;
    _highlightWidth = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = child!.size;
    } else {
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (child == null) return;

    final width = size.width.toInt();
    final height = size.height.toInt();

    if (width <= 0 || height <= 0) {
      child!.paintWithContext(canvas, offset);
      return;
    }

    // Create a temporary buffer for the child
    final tempBuffer = Buffer(width, height);
    final tempCanvas = TerminalCanvas(
      tempBuffer,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Paint child to temporary buffer
    child!.paintWithContext(tempCanvas, Offset.zero);

    // Calculate shimmer position based on progress
    // The shimmer travels from left-bottom to right-top (diagonal)
    final totalDiagonal = width + height * _angle;
    final shimmerCenter =
        -_highlightWidth + _progress * (totalDiagonal + _highlightWidth * 2);

    // Now paint from temp buffer to real canvas with shimmer effect
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final cell = tempBuffer.getCell(x, y);

        // Skip empty cells
        if (cell.char == ' ' && cell.style.backgroundColor == null) {
          continue;
        }

        // Calculate distance from shimmer line (diagonal)
        // The shimmer line moves left-to-right, leaning right (like \)
        final cellDiagonalPos = x + y * _angle;
        final distFromShimmer = (cellDiagonalPos - shimmerCenter).abs();

        Color? newColor = cell.style.color;

        if (_progress >= 0 && distFromShimmer < _highlightWidth) {
          // Apply shimmer highlight
          final intensity = 1.0 - (distFromShimmer / _highlightWidth);
          final easedIntensity = math.sin(
            intensity * math.pi / 2,
          ); // Smooth falloff

          if (_highlightColor != null) {
            newColor = Color.lerp(
              cell.style.color ?? _baseColor ?? Colors.white,
              _highlightColor!,
              easedIntensity,
            );
          } else {
            // Default: brighten the existing color towards white
            final baseCol = cell.style.color ?? _baseColor ?? Colors.white;
            newColor = _brighten(baseCol, easedIntensity * 0.8);
          }
        }

        final newStyle = TextStyle(
          color: newColor,
          backgroundColor: cell.style.backgroundColor,
          fontWeight: cell.style.fontWeight,
          fontStyle: cell.style.fontStyle,
          decoration: cell.style.decoration,
          reverse: cell.style.reverse,
        );

        canvas.drawText(
          Offset(offset.dx + x, offset.dy + y),
          cell.char,
          style: newStyle,
        );
      }
    }
  }

  /// Brighten a color by blending it towards white
  Color _brighten(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount) ?? color;
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    if (child != null) {
      return child!.hitTest(result, position: position);
    }
    return false;
  }
}
