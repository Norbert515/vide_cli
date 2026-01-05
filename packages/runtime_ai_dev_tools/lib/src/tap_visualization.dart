import 'package:flutter/material.dart';

/// Singleton service to manage tap visualization overlays
class TapVisualizationService {
  static final TapVisualizationService _instance =
      TapVisualizationService._internal();

  factory TapVisualizationService() => _instance;

  TapVisualizationService._internal();

  OverlayEntry? _currentOverlay;
  OverlayEntry? _persistentCursorOverlay;
  OverlayEntry? _scrollPathOverlay;
  OverlayEntry? _scrollEndIndicatorOverlay;
  GlobalKey<OverlayState>? _overlayKey;

  /// Register the overlay key from DebugOverlayWrapper
  void setOverlayKey(GlobalKey<OverlayState> key) {
    _overlayKey = key;
    print('✅ [TapVisualization] Overlay key registered');
  }

  /// Shows a tap visualization at the specified position
  void showTapAt(BuildContext context, double x, double y) {
    // Remove any existing overlay
    _currentOverlay?.remove();
    _currentOverlay = null;

    // Create new overlay entry
    _currentOverlay = OverlayEntry(
      builder: (context) => _TapVisualization(
        x: x,
        y: y,
        onComplete: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    // Insert overlay after current frame to avoid interfering with event dispatch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_currentOverlay != null) {
          // Use our custom overlay if available, otherwise fall back to context-based lookup
          final overlayState = _overlayKey?.currentState ?? Overlay.of(context);
          overlayState.insert(_currentOverlay!);
          print('✅ [TapVisualization] Overlay inserted successfully');
        }
      } catch (e) {
        print('⚠️  [TapVisualization] Failed to insert overlay: $e');
      }
    });
  }

  /// Clears any active overlay
  void clear() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Sets a persistent cursor at the specified position that stays visible until explicitly cleared
  /// This is useful for screenshots so the agent can see where the tap occurred
  void setPersistentCursor(BuildContext context, double x, double y) {
    // Remove any existing persistent cursor
    clearPersistentCursor();

    // Create new persistent cursor overlay
    _persistentCursorOverlay = OverlayEntry(
      builder: (context) => _PersistentCursor(x: x, y: y),
    );

    // Insert overlay after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_persistentCursorOverlay != null) {
          final overlayState = _overlayKey?.currentState ?? Overlay.of(context);
          overlayState.insert(_persistentCursorOverlay!);
          print('✅ [TapVisualization] Persistent cursor set at ($x, $y)');
        }
      } catch (e) {
        print('⚠️  [TapVisualization] Failed to insert persistent cursor: $e');
      }
    });
  }

  /// Clears the persistent cursor overlay
  void clearPersistentCursor() {
    _persistentCursorOverlay?.remove();
    _persistentCursorOverlay = null;
  }

  /// Shows an animated scroll path from start to end
  void showScrollPath(
      BuildContext context, Offset start, Offset end, Duration duration) {
    // Remove any existing scroll path overlay
    _scrollPathOverlay?.remove();
    _scrollPathOverlay = null;

    // Create new overlay entry for scroll path animation
    _scrollPathOverlay = OverlayEntry(
      builder: (context) => _ScrollPathVisualization(
        start: start,
        end: end,
        duration: duration,
        onComplete: () {
          _scrollPathOverlay?.remove();
          _scrollPathOverlay = null;
        },
      ),
    );

    // Insert overlay after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_scrollPathOverlay != null) {
          final overlayState = _overlayKey?.currentState ?? Overlay.of(context);
          overlayState.insert(_scrollPathOverlay!);
          print(
              '✅ [TapVisualization] Scroll path overlay inserted successfully');
        }
      } catch (e) {
        print(
            '⚠️  [TapVisualization] Failed to insert scroll path overlay: $e');
      }
    });
  }

  /// Sets a persistent indicator showing scroll start and end positions
  void setScrollEndIndicator(BuildContext context, Offset start, Offset end) {
    // Remove any existing scroll end indicator
    clearScrollEndIndicator();

    _scrollEndIndicatorOverlay = OverlayEntry(
      builder: (context) => _ScrollEndIndicator(start: start, end: end),
    );

    // Insert overlay after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_scrollEndIndicatorOverlay != null) {
          final overlayState = _overlayKey?.currentState ?? Overlay.of(context);
          overlayState.insert(_scrollEndIndicatorOverlay!);
          print('✅ [TapVisualization] Scroll end indicator set');
        }
      } catch (e) {
        print(
            '⚠️  [TapVisualization] Failed to insert scroll end indicator: $e');
      }
    });
  }

  /// Clears the scroll end indicator overlay
  void clearScrollEndIndicator() {
    _scrollEndIndicatorOverlay?.remove();
    _scrollEndIndicatorOverlay = null;
  }

  /// Clears the scroll path overlay
  void clearScrollPath() {
    _scrollPathOverlay?.remove();
    _scrollPathOverlay = null;
  }
}

/// Widget that displays the tap visualization animation
class _TapVisualization extends StatefulWidget {
  final double x;
  final double y;
  final VoidCallback onComplete;

  const _TapVisualization({
    required this.x,
    required this.y,
    required this.onComplete,
  });

  @override
  State<_TapVisualization> createState() => _TapVisualizationState();
}

class _TapVisualizationState extends State<_TapVisualization>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 100.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                left: widget.x - _scaleAnimation.value / 2,
                top: widget.y - _scaleAnimation.value / 2,
                child: Container(
                  width: _scaleAnimation.value,
                  height: _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue
                          .withValues(alpha: _opacityAnimation.value),
                      width: 2,
                    ),
                    color: Colors.blue
                        .withValues(alpha: _opacityAnimation.value * 0.3),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Widget that displays a persistent cursor indicator
/// This stays visible until explicitly cleared, useful for screenshots
class _PersistentCursor extends StatelessWidget {
  final double x;
  final double y;

  const _PersistentCursor({
    required this.x,
    required this.y,
  });

  static const double _innerDotSize = 8.0;
  static const double _crosshairLength = 20.0;
  static const double _crosshairThickness = 2.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Crosshair horizontal line
          Positioned(
            left: x - _crosshairLength / 2,
            top: y - _crosshairThickness / 2,
            child: Container(
              width: _crosshairLength,
              height: _crosshairThickness,
              color: Colors.deepOrange,
            ),
          ),
          // Crosshair vertical line
          Positioned(
            left: x - _crosshairThickness / 2,
            top: y - _crosshairLength / 2,
            child: Container(
              width: _crosshairThickness,
              height: _crosshairLength,
              color: Colors.deepOrange,
            ),
          ),
          // Center dot with border
          Positioned(
            left: x - _innerDotSize / 2,
            top: y - _innerDotSize / 2,
            child: Container(
              width: _innerDotSize,
              height: _innerDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepOrange,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that displays an animated scroll path being drawn
class _ScrollPathVisualization extends StatefulWidget {
  final Offset start;
  final Offset end;
  final Duration duration;
  final VoidCallback onComplete;

  const _ScrollPathVisualization({
    required this.start,
    required this.end,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_ScrollPathVisualization> createState() =>
      _ScrollPathVisualizationState();
}

class _ScrollPathVisualizationState extends State<_ScrollPathVisualization>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Total animation: draw the line, then hold briefly, then fade
    final totalDuration = widget.duration + const Duration(milliseconds: 500);

    _controller = AnimationController(
      duration: totalDuration,
      vsync: this,
    );

    // Line drawing happens during the scroll duration
    final drawEndTime =
        widget.duration.inMilliseconds / totalDuration.inMilliseconds;
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, drawEndTime, curve: Curves.linear),
    ));

    // Fade out happens after the line is drawn
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(drawEndTime, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ScrollPathPainter(
              start: widget.start,
              end: widget.end,
              progress: _progressAnimation.value,
              opacity: _fadeAnimation.value,
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter that draws an animated scroll path with arrow
class _ScrollPathPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress;
  final double opacity;

  _ScrollPathPainter({
    required this.start,
    required this.end,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = Colors.green.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Calculate current end position based on progress
    final currentEnd = Offset(
      start.dx + (end.dx - start.dx) * progress,
      start.dy + (end.dy - start.dy) * progress,
    );

    // Draw the line
    canvas.drawLine(start, currentEnd, paint);

    // Draw start circle
    final circlePaint = Paint()
      ..color = Colors.green.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 6, circlePaint);

    // Draw arrowhead at current position if we have progress
    if (progress > 0.1) {
      _drawArrowhead(canvas, currentEnd, paint);
    }
  }

  void _drawArrowhead(Canvas canvas, Offset tip, Paint paint) {
    final direction = (end - start).direction;
    const arrowSize = 12.0;
    const arrowAngle = 0.5; // radians

    final point1 = Offset(
      tip.dx - arrowSize * cos(direction - arrowAngle),
      tip.dy - arrowSize * sin(direction - arrowAngle),
    );
    final point2 = Offset(
      tip.dx - arrowSize * cos(direction + arrowAngle),
      tip.dy - arrowSize * sin(direction + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(point1.dx, point1.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(point2.dx, point2.dy);

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(_ScrollPathPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}

/// Widget that displays a persistent scroll end indicator
class _ScrollEndIndicator extends StatelessWidget {
  final Offset start;
  final Offset end;

  const _ScrollEndIndicator({
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScrollEndPainter(start: start, end: end),
      ),
    );
  }
}

/// Custom painter for the persistent scroll indicator
class _ScrollEndPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _ScrollEndPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw line
    final linePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, linePaint);

    // Draw start circle (hollow)
    final startPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(start, 8, startPaint);

    // Draw end circle (filled)
    final endPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(end, 6, endPaint);

    // Draw arrow on line
    _drawArrowhead(canvas, end, linePaint);
  }

  void _drawArrowhead(Canvas canvas, Offset tip, Paint paint) {
    final direction = (end - start).direction;
    const arrowSize = 14.0;
    const arrowAngle = 0.5;

    final point1 = Offset(
      tip.dx - arrowSize * cos(direction - arrowAngle),
      tip.dy - arrowSize * sin(direction - arrowAngle),
    );
    final point2 = Offset(
      tip.dx - arrowSize * cos(direction + arrowAngle),
      tip.dy - arrowSize * sin(direction + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(point1.dx, point1.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(point2.dx, point2.dy);

    final arrowPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_ScrollEndPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}

// Math functions for arrow drawing
double cos(double radians) => _cos(radians);
double sin(double radians) => _sin(radians);

double _cos(double x) {
  // Simple cosine using Taylor series approximation
  x = x % (2 * 3.14159265359);
  double result = 1.0;
  double term = 1.0;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i - 1) * (2 * i));
    result += term;
  }
  return result;
}

double _sin(double x) {
  // Simple sine using Taylor series approximation
  x = x % (2 * 3.14159265359);
  double result = x;
  double term = x;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}
