import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Service for capturing screenshots of the app.
///
/// Uses the render tree to capture what's currently displayed,
/// similar to the pattern in runtime_ai_dev_tools.
class ScreenshotService {
  /// The global key for the repaint boundary wrapping the user's app.
  final GlobalKey repaintBoundaryKey;

  ScreenshotService({required this.repaintBoundaryKey});

  /// Capture a screenshot and return it as a [ui.Image].
  Future<ui.Image> capture({double pixelRatio = 2.0}) async {
    final boundary =
        repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary != null) {
      return await boundary.toImage(pixelRatio: pixelRatio);
    }

    // Fallback: traverse from root
    final renderObject = WidgetsBinding.instance.rootElement
        ?.findRenderObject();
    if (renderObject == null) {
      throw StateError('No render object found for screenshot');
    }

    RenderObject? current = renderObject;
    while (current != null && current is! RenderRepaintBoundary) {
      current = current.parent;
    }

    if (current is RenderRepaintBoundary) {
      return await current.toImage(pixelRatio: pixelRatio);
    }

    // Last resort: build scene from layer
    final layer = renderObject.debugLayer;
    if (layer == null) {
      throw StateError('No layer found for screenshot');
    }

    final scene = layer.buildScene(ui.SceneBuilder());
    final image = await scene.toImage(
      renderObject.paintBounds.width.ceil(),
      renderObject.paintBounds.height.ceil(),
    );
    scene.dispose();
    return image;
  }

  /// Capture a screenshot and return it as base64-encoded PNG.
  Future<String> captureAsBase64({double pixelRatio = 2.0}) async {
    final image = await capture(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode screenshot');
    }

    return base64Encode(byteData.buffer.asUint8List());
  }

  /// Capture and return raw PNG bytes.
  Future<List<int>> captureAsBytes({double pixelRatio = 2.0}) async {
    final image = await capture(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode screenshot');
    }

    return byteData.buffer.asUint8List();
  }
}
