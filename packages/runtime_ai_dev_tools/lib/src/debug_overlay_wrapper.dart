import 'package:flutter/material.dart';
import 'tap_visualization.dart';

/// Wraps the app with a custom overlay for tap visualization
///
/// This widget creates its own overlay at the root of the widget tree,
/// giving us full control over tap visualization without relying on
/// Navigator's overlay or MaterialApp's overlay.
class DebugOverlayWrapper extends StatefulWidget {
  final Widget child;

  const DebugOverlayWrapper({
    super.key,
    required this.child,
  });

  @override
  State<DebugOverlayWrapper> createState() => _DebugOverlayWrapperState();
}

class _DebugOverlayWrapperState extends State<DebugOverlayWrapper> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();

  @override
  void initState() {
    super.initState();
    // Register our overlay with the tap visualization service
    TapVisualizationService().setOverlayKey(_overlayKey);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        key: _overlayKey,
        initialEntries: [
          OverlayEntry(
            builder: (context) => widget.child,
          ),
        ],
      ),
    );
  }
}
