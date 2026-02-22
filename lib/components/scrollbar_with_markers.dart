import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// A colored marker to display on the scrollbar track.
class ScrollbarMarker {
  const ScrollbarMarker({
    required this.position,
    required this.totalPositions,
    required this.color,
  });

  /// The position of this marker (e.g. line number, 0-indexed).
  final int position;

  /// The total number of positions (e.g. total lines in the file).
  final int totalPositions;

  /// The color to draw this marker in.
  final Color color;
}

/// A scrollbar that displays colored markers on the track.
///
/// Works identically to [Scrollbar] but accepts a list of [ScrollbarMarker]s
/// that are drawn on the track at their proportional positions — like VS Code's
/// scrollbar annotations for git changes, search results, etc.
class ScrollbarWithMarkers extends StatefulComponent {
  const ScrollbarWithMarkers({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility = false,
    this.thumbColor,
    this.trackColor,
    this.markers = const [],
  });

  final Component child;
  final ScrollController? controller;
  final bool thumbVisibility;
  final Color? thumbColor;
  final Color? trackColor;
  final List<ScrollbarMarker> markers;

  @override
  State<ScrollbarWithMarkers> createState() => _ScrollbarWithMarkersState();
}

class _ScrollbarWithMarkersState extends State<ScrollbarWithMarkers> {
  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = component.controller;
  }

  @override
  void didUpdateComponent(ScrollbarWithMarkers oldWidget) {
    super.didUpdateComponent(oldWidget);
    if (component.controller != oldWidget.controller) {
      _controller = component.controller;
    }
  }

  @override
  Component build(BuildContext context) {
    return _ScrollbarWithMarkersRenderObjectWidget(
      controller: _controller,
      thumbVisibility: component.thumbVisibility,
      trackColor: component.trackColor,
      thumbColor: component.thumbColor,
      markers: component.markers,
      child: component.child,
    );
  }
}

class _ScrollbarWithMarkersRenderObjectWidget
    extends SingleChildRenderObjectComponent {
  const _ScrollbarWithMarkersRenderObjectWidget({
    required this.controller,
    required this.thumbVisibility,
    this.trackColor,
    this.thumbColor,
    required this.markers,
    required super.child,
  });

  final ScrollController? controller;
  final bool thumbVisibility;
  final Color? trackColor;
  final Color? thumbColor;
  final List<ScrollbarMarker> markers;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final theme = TuiTheme.of(context);
    return _RenderScrollbarWithMarkers(
      controller: controller,
      thumbVisibility: thumbVisibility,
      trackColor: trackColor ?? theme.surface,
      thumbColor: thumbColor ?? theme.onSurface,
      markers: markers,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderScrollbarWithMarkers renderObject,
  ) {
    final theme = TuiTheme.of(context);
    renderObject
      ..controller = controller
      ..thumbVisibility = thumbVisibility
      ..trackColor = trackColor ?? theme.surface
      ..thumbColor = thumbColor ?? theme.onSurface
      ..markers = markers;
  }
}

class _RenderScrollbarWithMarkers extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  _RenderScrollbarWithMarkers({
    ScrollController? controller,
    required bool thumbVisibility,
    required Color trackColor,
    required Color thumbColor,
    required List<ScrollbarMarker> markers,
  })  : _controller = controller,
        _thumbVisibility = thumbVisibility,
        _trackColor = trackColor,
        _thumbColor = thumbColor,
        _markers = markers {
    _controller?.addListener(_handleScrollUpdate);
  }

  static const double _scrollbarThickness = 1.0;
  static const double _markerThickness = 1.0;
  static const double _totalThickness = _scrollbarThickness + _markerThickness;

  ScrollController? _controller;
  set controller(ScrollController? value) {
    if (_controller != value) {
      _controller?.removeListener(_handleScrollUpdate);
      _controller = value;
      _controller?.addListener(_handleScrollUpdate);
      markNeedsPaint();
    }
  }

  bool _thumbVisibility;
  set thumbVisibility(bool value) {
    if (_thumbVisibility != value) {
      _thumbVisibility = value;
      markNeedsPaint();
    }
  }

  Color _trackColor;
  set trackColor(Color value) {
    if (_trackColor != value) {
      _trackColor = value;
      markNeedsPaint();
    }
  }

  Color _thumbColor;
  set thumbColor(Color value) {
    if (_thumbColor != value) {
      _thumbColor = value;
      markNeedsPaint();
    }
  }

  List<ScrollbarMarker> _markers;
  set markers(List<ScrollbarMarker> value) {
    _markers = value;
    markNeedsPaint();
  }

  bool get _isReversed => _controller?.isReversed ?? false;

  void _handleScrollUpdate() {
    markNeedsPaint();
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleScrollUpdate);
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) {
    return position.dx >= size.width - _totalThickness;
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    final reservedWidth =
        _markers.isEmpty ? _scrollbarThickness : _totalThickness;

    final childConstraints = BoxConstraints(
      minWidth: math.max(0, constraints.minWidth - reservedWidth),
      maxWidth: math.max(0, constraints.maxWidth - reservedWidth),
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );

    child!.layout(childConstraints, parentUsesSize: true);

    size = constraints.constrain(Size(
      child!.size.width + reservedWidth,
      child!.size.height,
    ));
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (child == null) return;

    child!.paint(canvas, offset);

    if (_controller != null && _thumbVisibility) {
      _paintScrollbar(canvas, offset);
    }
  }

  void _paintScrollbar(TerminalCanvas canvas, Offset offset) {
    final controller = _controller!;

    if (controller.maxScrollExtent <= 0) return;

    final hasMarkers = _markers.isNotEmpty;
    final scrollbarX = size.width - _scrollbarThickness;
    final markerX = hasMarkers ? scrollbarX - _markerThickness : scrollbarX;
    final scrollbarHeight = size.height;

    // 1. Draw scrollbar track
    for (int y = 0; y < scrollbarHeight.toInt(); y++) {
      canvas.drawText(
        offset + Offset(scrollbarX, y.toDouble()),
        '│',
        style: TextStyle(color: _trackColor),
      );
    }

    // 2. Draw markers on a separate column to the left of the scrollbar
    if (hasMarkers) {
      for (final marker in _markers) {
        if (marker.totalPositions <= 0) continue;
        final markerY =
            (marker.position / marker.totalPositions * scrollbarHeight)
                .clamp(0, scrollbarHeight - 1)
                .toInt();
        canvas.drawText(
          offset + Offset(markerX, markerY.toDouble()),
          '▐',
          style: TextStyle(color: marker.color),
        );
      }
    }

    // 3. Draw arrows
    if (scrollbarHeight >= 3) {
      final topArrowActive =
          _isReversed ? !controller.atEnd : !controller.atStart;
      final bottomArrowActive =
          _isReversed ? !controller.atStart : !controller.atEnd;

      canvas.drawText(
        offset + Offset(scrollbarX, 0),
        '▲',
        style: TextStyle(
          color: topArrowActive ? _thumbColor : _trackColor,
        ),
      );

      canvas.drawText(
        offset + Offset(scrollbarX, scrollbarHeight - 1),
        '▼',
        style: TextStyle(
          color: bottomArrowActive ? _thumbColor : _trackColor,
        ),
      );
    }

    // 4. Draw thumb on top of scrollbar track
    final scrollFraction = controller.viewportDimension /
        (controller.maxScrollExtent + controller.viewportDimension);
    final thumbHeight = math.max(1.0, scrollbarHeight * scrollFraction);

    double thumbOffset;
    if (_isReversed) {
      final scrollOffset =
          1.0 - (controller.offset / controller.maxScrollExtent);
      thumbOffset = scrollOffset * (scrollbarHeight - thumbHeight);
    } else {
      final scrollOffset = controller.offset / controller.maxScrollExtent;
      thumbOffset = scrollOffset * (scrollbarHeight - thumbHeight);
    }

    final thumbStart = thumbOffset.toInt();
    final thumbEnd = math.min(
      (thumbOffset + thumbHeight).toInt(),
      scrollbarHeight.toInt(),
    );

    for (int y = thumbStart; y < thumbEnd; y++) {
      canvas.drawText(
        offset + Offset(scrollbarX, y.toDouble()),
        '█',
        style: TextStyle(color: _thumbColor),
      );
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    if (child == null) return false;

    if (position.dx >= size.width - _totalThickness) {
      return false;
    }

    return child!.hitTest(result, position: position);
  }
}
