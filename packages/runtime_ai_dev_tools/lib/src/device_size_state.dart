import 'package:flutter/widgets.dart';

/// Settings for device size override
class DeviceSizeSettings {
  final double width;
  final double height;
  final double devicePixelRatio;
  final bool showFrame;

  const DeviceSizeSettings({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    this.showFrame = true,
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'devicePixelRatio': devicePixelRatio,
        'showFrame': showFrame,
      };
}

/// Global state notifier for device size settings
///
/// This allows service extensions to update the device size
/// and the widget tree to listen for changes.
class DeviceSizeStateNotifier extends ChangeNotifier {
  DeviceSizeSettings? _settings;

  /// Current device size settings, null if using native size
  DeviceSizeSettings? get settings => _settings;

  /// Whether a custom device size is currently active
  bool get hasOverride => _settings != null;

  /// Set a custom device size
  void setDeviceSize({
    required double width,
    required double height,
    double? devicePixelRatio,
    bool showFrame = true,
  }) {
    _settings = DeviceSizeSettings(
      width: width,
      height: height,
      devicePixelRatio: devicePixelRatio ?? 1.0,
      showFrame: showFrame,
    );
    notifyListeners();
  }

  /// Reset to native device size
  void resetDeviceSize() {
    _settings = null;
    notifyListeners();
  }
}

/// Global instance of the device size state notifier
///
/// This singleton allows service extensions to update the state
/// from anywhere in the codebase.
final deviceSizeState = DeviceSizeStateNotifier();
