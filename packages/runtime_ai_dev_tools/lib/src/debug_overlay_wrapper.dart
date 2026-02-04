import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'device_size_state.dart';
import 'tap_visualization.dart';
import 'theme_extension.dart';
import 'locale_extension.dart';

/// Wraps the app with a custom overlay for tap visualization
///
/// This widget creates its own overlay at the root of the widget tree,
/// giving us full control over tap visualization without relying on
/// Navigator's overlay or MaterialApp's overlay.
///
/// It also listens to device size, theme mode, and locale overrides,
/// applying them via MediaQuery when set.
class DebugOverlayWrapper extends StatefulWidget {
  final Widget child;

  const DebugOverlayWrapper({super.key, required this.child});

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
    // Listen for device size changes
    deviceSizeState.addListener(_onStateChanged);
    // Listen to theme and locale changes
    themeModeNotifier.addListener(_onStateChanged);
    localeNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    deviceSizeState.removeListener(_onStateChanged);
    themeModeNotifier.removeListener(_onStateChanged);
    localeNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  /// Build the brightness override based on theme mode
  Brightness? _getBrightnessOverride() {
    switch (themeModeNotifier.value) {
      case ThemeModeOverride.light:
        return Brightness.light;
      case ThemeModeOverride.dark:
        return Brightness.dark;
      case ThemeModeOverride.system:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = deviceSizeState.settings;

    Widget child = widget.child;

    // Apply locale override if set
    final localeOverride = localeNotifier.value;
    if (localeOverride != null) {
      child = Localizations.override(
        context: context,
        locale: Locale(localeOverride.languageCode, localeOverride.countryCode),
        child: child,
      );
    }

    // Apply brightness override via MediaQuery
    final brightnessOverride = _getBrightnessOverride();
    if (brightnessOverride != null) {
      child = Builder(
        builder: (context) {
          // Get the existing MediaQuery data or create default
          final existingData = MediaQuery.maybeOf(context) ??
              MediaQueryData.fromView(
                  ui.PlatformDispatcher.instance.views.first);

          return MediaQuery(
            data: existingData.copyWith(platformBrightness: brightnessOverride),
            child: child,
          );
        },
      );
    }

    Widget content = Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        key: _overlayKey,
        initialEntries: [OverlayEntry(builder: (context) => child)],
      ),
    );

    // If we have device size settings, wrap with MediaQuery override
    if (settings != null) {
      content = _DeviceSizeOverride(
        width: settings.width,
        height: settings.height,
        devicePixelRatio: settings.devicePixelRatio,
        showFrame: settings.showFrame,
        child: content,
      );
    }

    return content;
  }
}

/// Widget that overrides MediaQuery to simulate a specific device size
///
/// Uses MediaQuery override instead of FittedBox to ensure breakpoints
/// actually respond to the logical size, not just scale the pixels.
class _DeviceSizeOverride extends StatelessWidget {
  final double width;
  final double height;
  final double devicePixelRatio;
  final bool showFrame;
  final Widget child;

  const _DeviceSizeOverride({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    required this.showFrame,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Get the actual screen size
    final actualSize = MediaQuery.of(context).size;

    // Calculate scale to fit the device preview in the actual screen
    // Leave some margin if showing frame
    final marginFactor = showFrame ? 0.9 : 1.0;
    final scaleX = (actualSize.width * marginFactor) / width;
    final scaleY = (actualSize.height * marginFactor) / height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Don't scale up, only scale down
    final finalScale = scale > 1.0 ? 1.0 : scale;

    // Create the simulated MediaQueryData
    final simulatedMediaQuery = MediaQueryData(
      size: Size(width, height),
      devicePixelRatio: devicePixelRatio,
      // Scale padding proportionally to the device size
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      textScaler: MediaQuery.of(context).textScaler,
      platformBrightness: MediaQuery.of(context).platformBrightness,
      highContrast: MediaQuery.of(context).highContrast,
      accessibleNavigation: MediaQuery.of(context).accessibleNavigation,
      invertColors: MediaQuery.of(context).invertColors,
      disableAnimations: MediaQuery.of(context).disableAnimations,
      boldText: MediaQuery.of(context).boldText,
    );

    Widget deviceContent = MediaQuery(
      data: simulatedMediaQuery,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRect(child: child),
      ),
    );

    // Add visual device frame if requested
    if (showFrame) {
      deviceContent = Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF333333), width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: deviceContent,
        ),
      );
    }

    // Scale the device preview to fit the actual screen
    if (finalScale < 1.0) {
      deviceContent = Transform.scale(scale: finalScale, child: deviceContent);
    }

    // Center in the available space with a background
    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Center(child: deviceContent),
    );
  }
}
