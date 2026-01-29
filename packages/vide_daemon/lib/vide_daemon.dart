/// Persistent daemon service managing multiple vide sessions as sub-processes.
///
/// The daemon spawns each session as a separate vide_server process and
/// provides orchestration (create, list, stop sessions) while clients
/// connect directly to session processes for the data plane.
library;

export 'src/daemon/daemon_server.dart';
export 'src/daemon/session_process.dart';
export 'src/daemon/session_registry.dart';
export 'src/protocol/daemon_messages.dart';
export 'src/protocol/daemon_events.dart';
export 'src/client/daemon_client.dart';
