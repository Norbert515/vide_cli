/// Device size presets for responsive testing
class DevicePreset {
  final String name;
  final double width;
  final double height;
  final double devicePixelRatio;

  const DevicePreset({
    required this.name,
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'width': width,
        'height': height,
        'devicePixelRatio': devicePixelRatio,
      };
}

/// Standard device presets for common devices
class DevicePresets {
  DevicePresets._();

  static const iphoneSe = DevicePreset(
    name: 'iphone-se',
    width: 375,
    height: 667,
    devicePixelRatio: 2.0,
  );

  static const iphone14 = DevicePreset(
    name: 'iphone-14',
    width: 390,
    height: 844,
    devicePixelRatio: 3.0,
  );

  static const iphone14ProMax = DevicePreset(
    name: 'iphone-14-pro-max',
    width: 430,
    height: 932,
    devicePixelRatio: 3.0,
  );

  static const iphoneLandscape = DevicePreset(
    name: 'iphone-landscape',
    width: 844,
    height: 390,
    devicePixelRatio: 3.0,
  );

  static const ipadMini = DevicePreset(
    name: 'ipad-mini',
    width: 744,
    height: 1133,
    devicePixelRatio: 2.0,
  );

  static const ipadPro11 = DevicePreset(
    name: 'ipad-pro-11',
    width: 834,
    height: 1194,
    devicePixelRatio: 2.0,
  );

  static const ipadPro129 = DevicePreset(
    name: 'ipad-pro-12.9',
    width: 1024,
    height: 1366,
    devicePixelRatio: 2.0,
  );

  static const pixel7 = DevicePreset(
    name: 'pixel-7',
    width: 412,
    height: 915,
    devicePixelRatio: 2.625,
  );

  static const pixelFold = DevicePreset(
    name: 'pixel-fold',
    width: 841,
    height: 701,
    devicePixelRatio: 2.625,
  );

  static const desktopHd = DevicePreset(
    name: 'desktop-hd',
    width: 1280,
    height: 720,
    devicePixelRatio: 1.0,
  );

  static const desktopFullHd = DevicePreset(
    name: 'desktop-full-hd',
    width: 1920,
    height: 1080,
    devicePixelRatio: 1.0,
  );

  static const desktop2k = DevicePreset(
    name: 'desktop-2k',
    width: 2560,
    height: 1440,
    devicePixelRatio: 1.0,
  );

  /// All available presets
  static const List<DevicePreset> all = [
    iphoneSe,
    iphone14,
    iphone14ProMax,
    iphoneLandscape,
    ipadMini,
    ipadPro11,
    ipadPro129,
    pixel7,
    pixelFold,
    desktopHd,
    desktopFullHd,
    desktop2k,
  ];

  /// Get a preset by name, returns null if not found
  static DevicePreset? byName(String name) {
    for (final preset in all) {
      if (preset.name == name) {
        return preset;
      }
    }
    return null;
  }

  /// List of all preset names
  static List<String> get names => all.map((p) => p.name).toList();
}
