import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'tap_visualization.dart';

/// Registers the widget info service extension
///
/// This extension provides widget information at screen coordinates,
/// including source file location when available (debug mode with
/// --track-widget-creation enabled).
void registerWidgetInfoExtension() {
  print(
      '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getWidgetInfo');

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getWidgetInfo',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getWidgetInfo extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final xStr = parameters['x'];
        final yStr = parameters['y'];

        if (xStr == null || yStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameters: x and y',
          );
        }

        final x = double.tryParse(xStr);
        final y = double.tryParse(yStr);

        if (x == null || y == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid x or y coordinate',
          );
        }

        final result = _getWidgetInfoAtPosition(x, y);

        return developer.ServiceExtensionResponse.result(json.encode(result));
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] getWidgetInfo failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to get widget info: $e\n$stackTrace',
        );
      }
    },
  );
}

/// Get widget information at the specified screen coordinates
Map<String, dynamic> _getWidgetInfoAtPosition(double x, double y) {
  print('🔍 [RuntimeAiDevTools] Getting widget info at ($x, $y)');

  // Show inspection pulse animation
  TapVisualizationService().showInspectionPulse(x, y);

  final binding = WidgetsBinding.instance;
  final renderView = binding.renderViews.firstOrNull;

  if (renderView == null) {
    print('   ⚠️  No render view available');
    return {
      'status': 'error',
      'error': 'No render view available',
    };
  }

  // Perform hit test at the position
  final position = Offset(x, y);
  final result = HitTestResult();
  renderView.hitTest(result, position: position);

  if (result.path.isEmpty) {
    print('   ⚠️  No widgets found at position');
    return {
      'status': 'success',
      'widgets': <Map<String, dynamic>>[],
      'message': 'No widgets found at position ($x, $y)',
    };
  }

  print('   Found ${result.path.length} hit test entries');

  // Collect widget information from hit test results
  final widgets = <Map<String, dynamic>>[];
  final seenElements = <Element>{};

  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;

    // Find the Element that owns this RenderObject
    final element = _findElementForRenderObject(target);
    if (element == null) continue;

    // Skip if we've already processed this element
    if (seenElements.contains(element)) continue;
    seenElements.add(element);

    final widget = element.widget;
    final widgetInfo = _extractWidgetInfo(widget, element, target);
    if (widgetInfo != null) {
      widgets.add(widgetInfo);
    }
  }

  print('   ✅ Extracted info for ${widgets.length} widgets');

  return {
    'status': 'success',
    'position': {'x': x, 'y': y},
    'widgets': widgets,
  };
}

/// Find the Element that owns a RenderObject
Element? _findElementForRenderObject(RenderObject renderObject) {
  Element? result;

  void visitor(Element element) {
    if (element.renderObject == renderObject) {
      result = element;
      return;
    }
    if (result == null) {
      element.visitChildren(visitor);
    }
  }

  final binding = WidgetsBinding.instance;
  binding.rootElement?.visitChildren(visitor);

  return result;
}

/// Extract widget information including source location
Map<String, dynamic>? _extractWidgetInfo(
  Widget widget,
  Element element,
  RenderObject renderObject,
) {
  final widgetType = widget.runtimeType.toString();

  // Get the render box bounds if available
  Map<String, dynamic>? bounds;
  if (renderObject is RenderBox && renderObject.hasSize) {
    try {
      final transform = renderObject.getTransformTo(null);
      final topLeft = MatrixUtils.transformPoint(transform, Offset.zero);
      final size = renderObject.size;

      bounds = {
        'x': topLeft.dx,
        'y': topLeft.dy,
        'width': size.width,
        'height': size.height,
      };
    } catch (e) {
      // Ignore bounds extraction errors
    }
  }

  // Try to get creation location (requires --track-widget-creation)
  final creationLocation = _getCreationLocation(element);

  // Build the widget info map
  final info = <String, dynamic>{
    'type': widgetType,
    'key': widget.key?.toString(),
  };

  if (bounds != null) {
    info['bounds'] = bounds;
  }

  if (creationLocation != null) {
    info['creationLocation'] = creationLocation;
  }

  // Add the debug creator chain (useful for finding source)
  try {
    info['creatorChain'] = element.debugGetCreatorChain(5);
  } catch (e) {
    // Ignore if not available
  }

  // Add some useful widget-specific properties
  _addWidgetSpecificInfo(widget, info);

  return info;
}

/// Try to get the creation location from an Element
///
/// This works when Flutter is run with --track-widget-creation (default in debug)
/// Uses WidgetInspectorService to access location data.
Map<String, dynamic>? _getCreationLocation(Element element) {
  try {
    // WidgetInspectorService provides access to creation locations
    // when --track-widget-creation is enabled (default in debug mode)
    if (!WidgetInspectorService.instance.isWidgetCreationTracked()) {
      return null;
    }

    // The inspector service can select and inspect widgets
    // We use it to get the creation location data
    final widget = element.widget;

    // Try to get location via the debug representation
    // The widget's toString in debug mode includes location info
    final debugString = widget.toStringShort();

    // Parse location from debug string if present (format: "WidgetName(file.dart:line)")
    final match = RegExp(r'\(([^:]+):(\d+)\)$').firstMatch(debugString);
    if (match != null) {
      return {
        'file': match.group(1),
        'line': int.tryParse(match.group(2) ?? ''),
      };
    }

    // Alternative: use toDiagnosticsNode to get structured info
    final diagnostics = widget.toDiagnosticsNode();
    for (final property in diagnostics.getProperties()) {
      final name = property.name?.toLowerCase() ?? '';
      if (name.contains('location') || name.contains('source')) {
        final value = property.value;
        if (value != null) {
          return {'debug': value.toString()};
        }
      }
    }
  } catch (e) {
    // Location tracking not available or failed
    print('   ⚠️  Could not get creation location: $e');
  }
  return null;
}

/// Add widget-specific properties that might be useful for understanding the widget
void _addWidgetSpecificInfo(Widget widget, Map<String, dynamic> info) {
  // Add text content for Text widgets
  if (widget is Text) {
    info['text'] = widget.data ?? widget.textSpan?.toPlainText();
  }

  // Add label/hint for input widgets
  if (widget is EditableText) {
    info['text'] = widget.controller.text;
  }

  // Add semantics label if available
  if (widget is Semantics) {
    info['semanticsLabel'] = widget.properties.label;
  }

  // Add icon data for Icon widgets
  if (widget is Icon) {
    info['icon'] = widget.icon?.codePoint;
  }

  // Add image info
  if (widget is Image) {
    final imageProvider = widget.image;
    info['imageType'] = imageProvider.runtimeType.toString();
  }
}
