import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Registers the screenshot service extension
void registerScreenshotExtension() {
  print('🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.screenshot');

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.screenshot',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] screenshot extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');
      try {
        final image = await _captureScreenshot();
        final base64Image = await _imageToBase64(image);

        // Get the device pixel ratio from the Flutter window
        final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'image': base64Image,
            'devicePixelRatio': devicePixelRatio,
          }),
        );
      } catch (e, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to capture screenshot: $e\n$stackTrace',
        );
      }
    },
  );
}

/// Captures a screenshot of the root widget tree
Future<ui.Image> _captureScreenshot() async {
  final renderObject = WidgetsBinding.instance.rootElement?.findRenderObject();

  if (renderObject == null) {
    throw Exception('Root render object not found');
  }

  // Traverse up the tree to find a RenderRepaintBoundary
  RenderObject? current = renderObject;
  while (current != null && current is! RenderRepaintBoundary) {
    current = current.parent;
  }

  // If we found a RenderRepaintBoundary, use it
  if (current is RenderRepaintBoundary) {
    return await current.toImage(pixelRatio: 2.0);
  }

  // If no RenderRepaintBoundary found, use the layer approach
  // Get the layer from the render object and convert it to an image
  final layer = renderObject.debugLayer;
  if (layer == null) {
    throw Exception('No layer found on render object');
  }

  // Use the layer's buildScene to create an image
  final scene = layer.buildScene(ui.SceneBuilder());
  final image = await scene.toImage(
    renderObject.paintBounds.width.ceil(),
    renderObject.paintBounds.height.ceil(),
  );
  scene.dispose();

  return image;
}

/// Converts a UI image to base64-encoded PNG string
Future<String> _imageToBase64(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  if (byteData == null) {
    throw Exception('Failed to convert image to byte data');
  }

  final buffer = byteData.buffer.asUint8List();
  return base64Encode(buffer);
}
