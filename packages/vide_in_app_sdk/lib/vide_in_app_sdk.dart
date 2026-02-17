/// Embed Vide AI assistant directly into any Flutter app.
///
/// Wrap your app with [VideInApp] to embed it inside the Vide dev
/// environment with a collapsible top panel for AI-powered development
/// assistance, screenshot capture, annotations, and voice input.
///
/// ```dart
/// void main() {
///   runApp(
///     VideInApp(
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
library;

export 'src/widgets/vide_in_app.dart';
export 'src/widgets/chat_panel.dart';
export 'src/widgets/screenshot_canvas.dart';
export 'src/services/screenshot_service.dart';
export 'src/services/voice_input_service.dart';
export 'src/state/sdk_state.dart';
