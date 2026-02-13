/// Embed Vide AI assistant directly into any Flutter app.
///
/// Wrap your app with [VideInApp] to get a Wiredash-style overlay
/// that provides AI-powered development assistance with screenshot
/// capture, annotations, and voice input.
///
/// ```dart
/// void main() {
///   runApp(
///     VideInApp(
///       serverUrl: 'http://localhost:8080',
///       workingDirectory: '/path/to/project',
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
