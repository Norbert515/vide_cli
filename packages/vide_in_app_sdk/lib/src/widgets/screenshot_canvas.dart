import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A drawing stroke on the screenshot canvas.
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _Stroke({required this.points, required this.color, required this.width});
}

/// Full-screen overlay for viewing a screenshot and drawing annotations on it.
///
/// Users can draw freehand annotations with multiple colors, undo strokes,
/// and confirm or cancel. The annotated image is returned as PNG bytes.
class ScreenshotCanvas extends StatefulWidget {
  /// The captured screenshot as a raw ui.Image.
  final ui.Image screenshot;

  /// Called when the user confirms the annotation.
  /// Receives the final composited image as PNG bytes.
  final ValueChanged<Uint8List> onConfirm;

  /// Called when the user cancels.
  final VoidCallback onCancel;

  const ScreenshotCanvas({
    super.key,
    required this.screenshot,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ScreenshotCanvas> createState() => _ScreenshotCanvasState();
}

class _ScreenshotCanvasState extends State<ScreenshotCanvas> {
  final List<_Stroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _currentColor = Colors.red;
  final double _strokeWidth = 3.0;

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.white,
    Colors.black,
  ];

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
    }
  }

  Future<void> _confirm() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final imageWidth = widget.screenshot.width.toDouble();
    final imageHeight = widget.screenshot.height.toDouble();

    // Draw the screenshot
    canvas.drawImage(widget.screenshot, Offset.zero, Paint());

    // Get the render box for coordinate scaling
    final renderBox = context.findRenderObject() as RenderBox;
    final displaySize = renderBox.size;
    final scaleX = imageWidth / displaySize.width;
    final scaleY = imageHeight / displaySize.height;

    // Draw annotations scaled to the image resolution
    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width * scaleX
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(stroke.points[0].dx * scaleX, stroke.points[0].dy * scaleY),
          stroke.width * scaleX / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path();
        path.moveTo(stroke.points[0].dx * scaleX, stroke.points[0].dy * scaleY);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(
            stroke.points[i].dx * scaleX,
            stroke.points[i].dy * scaleY,
          );
        }
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final composited = await picture.toImage(
      imageWidth.ceil(),
      imageHeight.ceil(),
    );
    picture.dispose();

    final byteData = await composited.toByteData(
      format: ui.ImageByteFormat.png,
    );
    composited.dispose();

    if (byteData != null) {
      widget.onConfirm(byteData.buffer.asUint8List());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Screenshot + annotation canvas
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _currentPoints = [details.localPosition];
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentPoints.add(details.localPosition);
              });
            },
            onPanEnd: (_) {
              setState(() {
                _strokes.add(
                  _Stroke(
                    points: List.of(_currentPoints),
                    color: _currentColor,
                    width: _strokeWidth,
                  ),
                );
                _currentPoints = [];
              });
            },
            child: CustomPaint(
              painter: _AnnotationPainter(
                screenshot: widget.screenshot,
                strokes: _strokes,
                currentPoints: _currentPoints,
                currentColor: _currentColor,
                strokeWidth: _strokeWidth,
              ),
            ),
          ),

          // Top toolbar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Cancel
                _ToolbarButton(icon: Icons.close, onTap: widget.onCancel),
                const Spacer(),
                // Undo
                _ToolbarButton(
                  icon: Icons.undo,
                  onTap: _strokes.isNotEmpty ? _undo : null,
                ),
                const SizedBox(width: 8),
                // Confirm
                _ToolbarButton(
                  icon: Icons.check,
                  color: Colors.green,
                  onTap: _confirm,
                ),
              ],
            ),
          ),

          // Color palette
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _colors.map((color) {
                    final isSelected = _currentColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _currentColor = color),
                      child: Container(
                        width: isSelected ? 32 : 28,
                        height: isSelected ? 32 : 28,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white30,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ToolbarButton({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(
            alpha: onTap != null ? 0.2 : 0.05,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: (color ?? Colors.white).withValues(
            alpha: onTap != null ? 1.0 : 0.3,
          ),
          size: 20,
        ),
      ),
    );
  }
}

/// Custom painter that draws the screenshot and annotation strokes.
class _AnnotationPainter extends CustomPainter {
  final ui.Image screenshot;
  final List<_Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double strokeWidth;

  _AnnotationPainter({
    required this.screenshot,
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw screenshot scaled to fit
    final srcRect = Rect.fromLTWH(
      0,
      0,
      screenshot.width.toDouble(),
      screenshot.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(screenshot, srcRect, dstRect, Paint());

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }

    // Draw current in-progress stroke
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, strokeWidth);
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(
        points[0],
        width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) => true;
}
