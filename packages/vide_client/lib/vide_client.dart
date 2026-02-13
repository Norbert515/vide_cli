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
/// // Listen to accumulated conversation state (recommended)
/// final agentId = session.state.agents.first.id;
/// session.conversationStream(agentId).listen((agentState) {
///   for (final entry in agentState.messages) {
///     print(entry.text); // Full accumulated text
///   }
/// });
/// ```
library;

export 'package:vide_interface/vide_interface.dart';

export 'src/client.dart';
export 'src/remote_vide_session.dart';
