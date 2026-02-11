/// Dart client library for connecting to Vide servers.
///
/// Use [VideClient] to connect to a server and create sessions:
///
/// ```dart
/// import 'package:vide_client/vide_client.dart';
///
/// final client = VideClient(port: 8080);
/// final session = await client.createSession(
///   initialMessage: 'Hello',
///   workingDirectory: '/path/to/project',
/// );
///
/// await for (final event in session.events) {
///   switch (event) {
///     case MessageEvent(:final content, :final isPartial):
///       if (!isPartial) print(content);
///     case TurnCompleteEvent():
///       break;
///   }
/// }
/// ```
library;

export 'package:vide_interface/vide_interface.dart';

export 'src/client.dart';
export 'src/remote_vide_session.dart';
export 'src/session.dart';
