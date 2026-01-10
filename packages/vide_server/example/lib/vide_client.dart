/// Client library for vide_server WebSocket API.
///
/// ```dart
/// import 'lib/vide_client.dart';
///
/// final client = VideClient(port: 8080);
/// await client.checkHealth();
///
/// final session = await client.createSession(
///   initialMessage: 'Hello',
///   workingDirectory: '/path/to/project',
/// );
///
/// session.events.listen((event) {
///   switch (event) {
///     case MessageEvent(:final content): print(content);
///     case DoneEvent(): print('Done');
///   }
/// });
///
/// session.send('Follow-up message');
/// await session.close();
/// ```
library;

export 'src/agent_info.dart';
export 'src/enums.dart';
export 'src/events.dart';
export 'src/vide_client.dart';
