import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Registry of actionable elements for ID-based interaction.
/// Elements are registered during tree traversal and can be looked up by ID.
class ActionableElementRegistry {
  ActionableElementRegistry._();
  static final instance = ActionableElementRegistry._();

  final _elements = <String, _RegisteredElement>{};

  void clear() => _elements.clear();

  void register(String id, Element element, Rect bounds) {
    _elements[id] = _RegisteredElement(element: element, bounds: bounds);
  }

  Offset? getCenterForId(String id) {
    final registered = _elements[id];
    if (registered == null) return null;
    return registered.bounds.center;
  }

  Element? getElementForId(String id) => _elements[id]?.element;
}

class _RegisteredElement {
  final Element element;
  final Rect bounds;
  _RegisteredElement({required this.element, required this.bounds});
}

/// Registers the actionable elements service extension.
///
/// This extension uses Flutter's Semantics tree to find truly visible
/// interactive elements - the same elements that screen readers see.
/// This correctly handles Navigator routes, dialogs, and all visibility cases.
void registerActionableElementsExtension() {
  print(
      '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getActionableElements');

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getActionableElements',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getActionableElements extension called');

      try {
        final result = _getActionableElements();
        return developer.ServiceExtensionResponse.result(json.encode(result));
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] getActionableElements failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to get actionable elements: $e\n$stackTrace',
        );
      }
    },
  );

  // Extension to tap an element by ID
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.tapElement',
    (String method, Map<String, String> parameters) async {
      final id = parameters['id'];
      if (id == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Missing required parameter: id',
        );
      }

      final center = ActionableElementRegistry.instance.getCenterForId(id);
      if (center == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Element not found with id: $id. Call getActionableElements first to refresh the registry.',
        );
      }

      // Return the coordinates - the caller will use the tap extension
      return developer.ServiceExtensionResponse.result(json.encode({
        'status': 'success',
        'id': id,
        'x': center.dx,
        'y': center.dy,
      }));
    },
  );
}

// Note: Semantics initialization is handled by DebugWidgetsFlutterBinding.
// This ensures the semantics tree is ready before getActionableElements is called.

/// Uses the Semantics tree to find truly visible actionable elements.
/// The semantics tree correctly handles Navigator routes, dialogs,
/// and all visibility cases - it's what screen readers see.
Map<String, dynamic> _getActionableElements() {
  print('🔍 [RuntimeAiDevTools] Scanning for actionable elements via Semantics tree...');

  final binding = WidgetsBinding.instance;
  final rootElement = binding.rootElement;

  if (rootElement == null) {
    return {
      'status': 'error',
      'error': 'No root element available',
    };
  }

  // Get screen size for visibility check
  // Note: Semantics tree uses PHYSICAL pixels, so we need to scale screen bounds
  final renderView = binding.renderViews.firstOrNull;
  final screenSize = renderView?.size ?? Size.zero;
  final dpr = binding.platformDispatcher.views.firstOrNull?.devicePixelRatio ?? 1.0;
  // Scale to physical pixels to match semantics tree coordinates
  final screenBounds = Rect.fromLTWH(0, 0, screenSize.width * dpr, screenSize.height * dpr);

  // Clear previous registry
  ActionableElementRegistry.instance.clear();

  // Build a map from SemanticsNode to Element for tap coordinate lookup
  final semanticsToElement = <SemanticsNode, Element>{};
  void buildSemanticsMap(Element element) {
    final ro = element.renderObject;
    if (ro != null) {
      final semantics = ro.debugSemantics;
      if (semantics != null) {
        semanticsToElement[semantics] = element;
      }
    }
    element.visitChildren(buildSemanticsMap);
  }
  rootElement.visitChildren(buildSemanticsMap);

  // Try to get semantics from the render view
  SemanticsNode? rootSemanticsNode;

  if (renderView != null) {
    // Force semantics update on the render view
    final pipelineOwner = renderView.owner;
    if (pipelineOwner != null) {
      pipelineOwner.flushSemantics();
    }
    // Get the semantics from the view's render object
    rootSemanticsNode = renderView.debugSemantics;
  }

  if (rootSemanticsNode == null) {
    print('   ⚠️ No semantics tree available, falling back to widget tree');
    return _getElementsFromWidgetTree(rootElement, screenBounds);
  }

  return _getElementsFromSemantics(rootSemanticsNode, semanticsToElement, screenBounds, dpr);
}

/// Traverse the semantics tree to find actionable elements.
/// This correctly filters out invisible elements (Navigator routes, etc.)
/// [dpr] is the device pixel ratio, used to convert physical->logical coordinates
Map<String, dynamic> _getElementsFromSemantics(
  SemanticsNode rootNode,
  Map<SemanticsNode, Element> semanticsToElement,
  Rect screenBounds,
  double dpr,
) {
  final counters = <String, int>{};
  String generateId(String type) {
    final count = counters[type] ?? 0;
    counters[type] = count + 1;
    return '${type}_$count';
  }

  final elements = <Map<String, dynamic>>[];
  final seenNodes = <SemanticsNode>{};

  void visitSemanticsNode(SemanticsNode node, Matrix4 transform) {
    // Skip if already seen
    if (seenNodes.contains(node)) return;
    seenNodes.add(node);

    // === KEY VISIBILITY CHECK ===
    // Skip invisible nodes - this is what filters Navigator routes!
    if (node.isInvisible) {
      return;
    }

    // Skip nodes with empty rects
    if (node.rect.isEmpty) {
      return;
    }

    // Calculate global bounds using transform
    final globalTransform = transform.multiplied(node.transform ?? Matrix4.identity());
    final localRect = node.rect;
    final topLeft = MatrixUtils.transformPoint(globalTransform, localRect.topLeft);
    final bottomRight = MatrixUtils.transformPoint(globalTransform, localRect.bottomRight);
    final globalBounds = Rect.fromPoints(topLeft, bottomRight);

    // Skip if completely off-screen
    if (!globalBounds.overlaps(screenBounds)) {
      // But still visit children
      node.visitChildren((child) {
        visitSemanticsNode(child, globalTransform);
        return true;
      });
      return;
    }

    // Convert physical pixel bounds to logical pixels for consistency
    final logicalBounds = Rect.fromLTRB(
      globalBounds.left / dpr,
      globalBounds.top / dpr,
      globalBounds.right / dpr,
      globalBounds.bottom / dpr,
    );

    // Extract element info from this semantics node
    final info = _extractFromSemanticsNode(node, logicalBounds, generateId);
    if (info != null) {
      // Register for tap lookup (use logical bounds)
      final element = semanticsToElement[node];
      if (element != null) {
        ActionableElementRegistry.instance.register(info['id'] as String, element, logicalBounds);
      } else {
        // Register with bounds only (still tappable via coordinates)
        ActionableElementRegistry.instance._elements[info['id'] as String] = _RegisteredElement(
          element: WidgetsBinding.instance.rootElement!,
          bounds: logicalBounds,
        );
      }
      elements.add(info);
    }

    // Visit children
    node.visitChildren((child) {
      visitSemanticsNode(child, globalTransform);
      return true;
    });
  }

  visitSemanticsNode(rootNode, Matrix4.identity());

  print('   ✅ Found ${elements.length} actionable elements (via Semantics tree)');

  return {
    'status': 'success',
    'elements': elements,
    'method': 'semantics',
  };
}

/// Extract actionable element info from a SemanticsNode.
Map<String, dynamic>? _extractFromSemanticsNode(
  SemanticsNode node,
  Rect globalBounds,
  String Function(String) generateId,
) {
  final data = node.getSemanticsData();

  // Check for actionable semantics
  final hasTap = data.hasAction(SemanticsAction.tap);
  final hasLongPress = data.hasAction(SemanticsAction.longPress);
  final hasSetText = data.hasAction(SemanticsAction.setText);
  final hasIncrease = data.hasAction(SemanticsAction.increase);
  final hasDecrease = data.hasAction(SemanticsAction.decrease);

  final isButton = data.hasFlag(SemanticsFlag.isButton);
  final isTextField = data.hasFlag(SemanticsFlag.isTextField);
  final isSlider = data.hasFlag(SemanticsFlag.isSlider);
  final isToggled = data.hasFlag(SemanticsFlag.hasToggledState);
  final isChecked = data.hasFlag(SemanticsFlag.hasCheckedState);
  final isLink = data.hasFlag(SemanticsFlag.isLink);

  // Skip non-actionable nodes
  final isActionable = hasTap || hasLongPress || hasSetText || hasIncrease || hasDecrease ||
      isButton || isTextField || isSlider || isToggled || isChecked || isLink;

  if (!isActionable) return null;

  // Determine type
  String type;
  if (isTextField) {
    type = 'textfield';
  } else if (isSlider) {
    type = 'slider';
  } else if (isChecked) {
    type = 'checkbox';
  } else if (isToggled) {
    type = 'switch';
  } else if (isButton) {
    type = 'button';
  } else if (isLink) {
    type = 'link';
  } else if (hasTap || hasLongPress) {
    type = 'tappable';
  } else {
    type = 'interactive';
  }

  final id = generateId(type);

  // Build info map
  final info = <String, dynamic>{
    'id': id,
    'type': type,
  };

  // Add label/text from semantics
  final label = data.label;
  if (label.isNotEmpty) {
    info['label'] = label;
  }

  final value = data.value;
  if (value.isNotEmpty) {
    info['value'] = value;
  }

  final hint = data.hint;
  if (hint.isNotEmpty) {
    info['hint'] = hint;
  }

  // Add state info
  if (isChecked) {
    info['checked'] = data.hasFlag(SemanticsFlag.isChecked);
  }
  if (isToggled) {
    info['toggled'] = data.hasFlag(SemanticsFlag.isToggled);
  }

  // Add bounds
  info['bounds'] = {
    'x': globalBounds.left.round(),
    'y': globalBounds.top.round(),
    'width': globalBounds.width.round(),
    'height': globalBounds.height.round(),
  };

  return info;
}

/// Alternative: Get actionable elements by traversing just the widget tree.
/// Used as a fallback when semantics isn't providing visibility info.
Map<String, dynamic> _getElementsFromWidgetTree(Element rootElement, Rect screenBounds) {
  final counters = <String, int>{};

  String generateId(String type) {
    final count = counters[type] ?? 0;
    counters[type] = count + 1;
    return '${type}_$count';
  }

  final elements = <Map<String, dynamic>>[];
  final seenElements = <Element>{};

  void visitElement(Element element) {
    // Skip if already seen
    if (seenElements.contains(element)) return;
    seenElements.add(element);

    final widget = element.widget;
    final renderObject = element.renderObject;

    // Check for Offstage widgets - skip their children if offstage
    if (widget is Offstage && widget.offstage) {
      return; // Don't traverse children of offstage widgets
    }

    // Also check the render object for offstage state (Navigator uses this)
    if (renderObject is RenderOffstage && renderObject.offstage) {
      return; // Don't traverse children of offstage render objects
    }

    // Check for Visibility widget
    if (widget is Visibility && !widget.visible) {
      return; // Don't traverse children of invisible widgets
    }

    // Check for Opacity - skip if fully transparent (both widget and render level)
    if (widget is Opacity && widget.opacity == 0.0) {
      return; // Don't traverse children of fully transparent widgets
    }
    if (renderObject is RenderOpacity && renderObject.opacity == 0.0) {
      return; // Don't traverse children of fully transparent render objects
    }

    final info = _extractActionableInfoFromWidget(widget, element, generateId, screenBounds);

    if (info != null) {
      elements.add(info);
    }

    // Continue traversing children
    element.visitChildren(visitElement);
  }

  rootElement.visitChildren(visitElement);

  print('   ✅ Found ${elements.length} actionable elements (via Widget tree)');

  return {
    'status': 'success',
    'elements': elements,
    'method': 'widget_tree',
  };
}

/// Extract actionable element info from widget if the widget is interactive.
/// Returns null for non-interactive widgets.
Map<String, dynamic>? _extractActionableInfoFromWidget(
  Widget widget,
  Element element,
  String Function(String type) generateId,
  Rect screenBounds,
) {
  // Get bounds first - we need this for registration
  Rect? bounds;
  final renderObject = element.renderObject;
  if (renderObject is RenderBox && renderObject.hasSize) {
    try {
      final transform = renderObject.getTransformTo(null);
      final topLeft = MatrixUtils.transformPoint(transform, Offset.zero);
      final size = renderObject.size;
      bounds = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
    } catch (e) {
      // Ignore bounds extraction errors
    }
  }

  // Skip elements with no bounds (not laid out)
  if (bounds == null) return null;

  // Skip elements that are completely off-screen
  if (!bounds.overlaps(screenBounds)) return null;

  // Skip elements with zero or negative size
  if (bounds.width <= 0 || bounds.height <= 0) return null;

  // Skip elements that are too small to tap (likely hidden or collapsed)
  if (bounds.width < 1 || bounds.height < 1) return null;

  // Check if the render object is actually painting (not clipped away)
  if (renderObject is RenderBox) {
    // Check if attached to render tree and needs paint
    if (!renderObject.attached) return null;
  }

  // Check for various interactive widget types
  final info = _matchWidget(widget, element, bounds);
  if (info == null) return null;

  // Generate ID and register for later lookup
  final id = generateId(info['type'] as String);
  info['id'] = id;

  // Register element for tapElement lookup
  ActionableElementRegistry.instance.register(id, element, bounds);

  return info;
}

/// Match widget to actionable type and extract relevant info.
Map<String, dynamic>? _matchWidget(Widget widget, Element element, Rect bounds) {
  // Material Buttons
  if (widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FilledButton) {
    return {
      'type': 'button',
      'label': _findChildText(element),
      'enabled': (widget as dynamic).enabled ?? true,
    };
  }

  if (widget is IconButton) {
    return {
      'type': 'icon_button',
      'tooltip': widget.tooltip,
      'enabled': widget.onPressed != null,
    };
  }

  if (widget is FloatingActionButton) {
    return {
      'type': 'fab',
      'tooltip': widget.tooltip,
      'label': _findChildText(element),
    };
  }

  // Text Input
  if (widget is TextField) {
    final decoration = widget.decoration;
    return {
      'type': 'textfield',
      'label': decoration?.labelText,
      'hint': decoration?.hintText,
      'obscured': widget.obscureText,
      'enabled': widget.enabled,
    };
  }

  // Selection controls
  if (widget is Checkbox) {
    return {
      'type': 'checkbox',
      'checked': widget.value,
      'enabled': widget.onChanged != null,
    };
  }

  if (widget is Radio) {
    return {
      'type': 'radio',
      'selected': widget.groupValue == widget.value,
      'enabled': widget.onChanged != null,
    };
  }

  if (widget is Switch) {
    return {
      'type': 'switch',
      'on': widget.value,
      'enabled': widget.onChanged != null,
    };
  }

  // Dropdown
  if (widget is DropdownButton) {
    return {
      'type': 'dropdown',
      'value': widget.value?.toString(),
      'hint': _getDropdownHint(widget),
    };
  }

  // List items
  if (widget is ListTile) {
    final titleWidget = widget.title;
    String? title;
    if (titleWidget is Text) {
      title = titleWidget.data;
    }
    return {
      'type': 'list_tile',
      'title': title,
      'subtitle': _getListTileSubtitle(widget),
      'enabled': widget.enabled,
      'selected': widget.selected,
    };
  }

  // Tabs
  if (widget is Tab) {
    return {
      'type': 'tab',
      'label': widget.text,
    };
  }

  // Navigation items
  if (widget is NavigationDestination) {
    return {
      'type': 'nav_item',
      'label': widget.label,
    };
  }

  // Chip
  if (widget is Chip || widget is ActionChip || widget is FilterChip || widget is ChoiceChip) {
    return {
      'type': 'chip',
      'label': _findChildText(element),
      'selected': widget is FilterChip ? widget.selected :
                  widget is ChoiceChip ? widget.selected : null,
    };
  }

  // Slider
  if (widget is Slider) {
    return {
      'type': 'slider',
      'value': widget.value,
      'min': widget.min,
      'max': widget.max,
    };
  }

  // PopupMenuButton
  if (widget is PopupMenuButton) {
    return {
      'type': 'popup_menu',
      'tooltip': widget.tooltip,
    };
  }

  // Generic tappable widgets (InkWell, GestureDetector with onTap)
  if (widget is InkWell && widget.onTap != null) {
    return {
      'type': 'tappable',
      'label': _findChildText(element),
    };
  }

  if (widget is GestureDetector && widget.onTap != null) {
    return {
      'type': 'tappable',
      'label': _findChildText(element),
    };
  }

  // Back button / Close button in AppBar
  if (widget is BackButton) {
    return {'type': 'back_button'};
  }

  if (widget is CloseButton) {
    return {'type': 'close_button'};
  }

  // ExpansionTile
  if (widget is ExpansionTile) {
    final titleWidget = widget.title;
    String? title;
    if (titleWidget is Text) {
      title = titleWidget.data;
    }
    return {
      'type': 'expansion_tile',
      'title': title,
    };
  }

  return null;
}

/// Find text content in child widgets.
String? _findChildText(Element element) {
  String? text;

  void visitor(Element child) {
    if (text != null) return;

    final widget = child.widget;
    if (widget is Text) {
      text = widget.data ?? widget.textSpan?.toPlainText();
      return;
    }
    if (widget is RichText) {
      text = widget.text.toPlainText();
      return;
    }

    child.visitChildren(visitor);
  }

  element.visitChildren(visitor);
  return text;
}

/// Get dropdown hint text.
String? _getDropdownHint(DropdownButton widget) {
  final hint = widget.hint;
  if (hint is Text) {
    return hint.data;
  }
  return null;
}

/// Get ListTile subtitle.
String? _getListTileSubtitle(ListTile widget) {
  final subtitle = widget.subtitle;
  if (subtitle is Text) {
    return subtitle.data;
  }
  return null;
}
