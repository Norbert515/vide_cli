import 'package:flutter/widgets.dart';
import 'src/screenshot_extension.dart';
import 'src/tap_extension.dart';
import 'src/type_extension.dart';
import 'src/scroll_extension.dart';
import 'src/debug_overlay_wrapper.dart';

/// Initialize runtime AI dev tools and run the app
///
/// This is the recommended way to use Runtime AI Dev Tools.
/// It wraps your app with a custom overlay for tap visualization
/// and automatically registers all service extensions.
///
/// Example:
/// ```dart
/// void main() {
///   runDebugApp(MyApp());
/// }
/// ```
void runDebugApp(Widget app) {
  RuntimeAiDevTools.runDebugApp(app);
}

/// Runtime AI dev tools for Flutter
///
/// Provides service extensions for AI-assisted app testing including:
/// - Screenshot capture
/// - Tap simulation with visualization
class RuntimeAiDevTools {
  RuntimeAiDevTools._();

  static bool _initialized = false;

  /// Initialize runtime AI dev tools and run the app
  ///
  /// This is the recommended way to use Runtime AI Dev Tools.
  /// It wraps your app with a custom overlay for tap visualization
  /// and automatically registers all service extensions.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   runDebugApp(MyApp());
  /// }
  /// ```
  static void runDebugApp(Widget app) {
    _init();
    runApp(DebugOverlayWrapper(child: app));
  }

  /// Initialize runtime AI dev tools (legacy method)
  ///
  /// **Deprecated:** Use `runDebugApp()` instead for better tap visualization.
  ///
  /// Call this at the very beginning of main() after ensureInitialized()
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   RuntimeAiDevTools.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  @Deprecated('Use runDebugApp() instead for better tap visualization')
  static void init() {
    _init();
  }

  /// Internal initialization
  static void _init() {
    if (_initialized) {
      print('⚠️ [RuntimeAiDevTools] Already initialized, skipping');
      return;
    }

    print('🔍 [RuntimeAiDevTools] Initializing...');

    WidgetsFlutterBinding.ensureInitialized();

    // Register service extensions immediately
    // Service extensions need to be registered before VM Service queries them
    print('🔧 [RuntimeAiDevTools] Registering service extensions...');
    registerScreenshotExtension();
    registerTapExtension();
    registerTypeExtension();
    registerScrollExtension();
    print('✅ [RuntimeAiDevTools] Service extensions registered');

    _initialized = true;
  }
}
