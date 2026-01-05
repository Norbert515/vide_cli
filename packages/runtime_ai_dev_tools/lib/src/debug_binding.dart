import 'package:flutter/widgets.dart';
import 'debug_overlay_wrapper.dart';

/// Custom binding that automatically wraps the root widget with DebugOverlayWrapper.
///
/// This binding intercepts the widget attachment process to inject the debug overlay
/// without requiring modification of the user's main.dart.
///
/// Usage in synthetic main:
/// ```dart
/// void main() {
///   DebugWidgetsFlutterBinding.ensureInitialized();
///   RuntimeAiDevTools.registerExtensions();
///   user_app.main();
/// }
/// ```
class DebugWidgetsFlutterBinding extends WidgetsFlutterBinding {
  /// Track if we've already wrapped to avoid double-wrapping
  bool _hasWrapped = false;

  /// Override wrapWithDefaultView to inject DebugOverlayWrapper BEFORE the View wrapper.
  /// This is called by runApp before scheduleAttachRootWidget.
  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    print('🔗 [DebugWidgetsFlutterBinding] wrapWithDefaultView called');
    if (_hasWrapped) {
      print('🔗 [DebugWidgetsFlutterBinding] Already wrapped, skipping');
      return super.wrapWithDefaultView(rootWidget);
    }
    _hasWrapped = true;
    print('🔗 [DebugWidgetsFlutterBinding] Wrapping with DebugOverlayWrapper');
    // Wrap the user's widget with DebugOverlayWrapper, then let the default View wrapper handle it
    return super.wrapWithDefaultView(DebugOverlayWrapper(child: rootWidget));
  }

  /// Returns an instance of [DebugWidgetsFlutterBinding], creating and
  /// initializing it if necessary.
  ///
  /// MUST be called before runApp() to ensure this binding is used.
  static WidgetsBinding ensureInitialized() {
    print('🔗 [DebugWidgetsFlutterBinding] ensureInitialized called');

    // Check if a binding already exists using the safe pattern
    // BindingBase.debugBindingType() is safe even when no binding exists
    final WidgetsBinding? existingBinding;
    try {
      existingBinding = WidgetsBinding.instance;
      print(
          '🔗 [DebugWidgetsFlutterBinding] Existing binding found: ${existingBinding.runtimeType}');
    } catch (e) {
      // No binding initialized yet - this is expected for first call
      print(
          '🔗 [DebugWidgetsFlutterBinding] No existing binding, creating DebugWidgetsFlutterBinding');
      DebugWidgetsFlutterBinding();
      print('🔗 [DebugWidgetsFlutterBinding] Created and initialized');
      return WidgetsBinding.instance;
    }

    // A binding already exists
    if (existingBinding is DebugWidgetsFlutterBinding) {
      print(
          '🔗 [DebugWidgetsFlutterBinding] Already using DebugWidgetsFlutterBinding');
      return existingBinding;
    }

    // Different binding exists - warn but return it
    print(
        '⚠️ [DebugWidgetsFlutterBinding] Different binding already initialized: ${existingBinding.runtimeType}');
    print(
        '⚠️ [DebugWidgetsFlutterBinding] DebugOverlayWrapper will NOT be automatically injected');
    return existingBinding;
  }
}
