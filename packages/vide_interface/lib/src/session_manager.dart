/// Abstract session manager interface for the Vide ecosystem.
///
/// Both local (in-process) and remote (daemon/WebSocket) session managers
/// implement this interface, providing a transport-independent API for
/// session lifecycle management (create, list, resume, delete).
library;

import 'models/vide_config.dart';
import 'models/vide_message.dart';
import 'session.dart';

/// Manages the lifecycle of [VideSession] instances.
///
/// This is the single abstraction for session lifecycle operations across
/// local and remote modes. UI code should depend on this interface rather
/// than on concrete implementations directly.
///
/// Implementations:
/// - `LocalVideSessionManager` (in vide_core) — in-process sessions
/// - `RemoteVideSessionManager` (in vide_client) — wraps daemon/WebSocket
///
/// Example:
/// ```dart
/// final manager = container.read(videSessionManagerProvider);
///
/// // Create a session — returns immediately, works optimistically
/// final session = await manager.createSession(
///   initialMessage: 'Fix the auth bug',
///   workingDirectory: '/path/to/project',
/// );
///
/// // List previous sessions
/// final sessions = await manager.listSessions();
///
/// // Resume an existing session
/// final resumed = await manager.resumeSession(sessions.first.id);
/// ```
abstract interface class VideSessionManager {
  /// Create a new session.
  ///
  /// Returns a [VideSession] that is immediately usable. For remote
  /// implementations, the session may still be connecting in the background,
  /// but callers don't need to care — [VideSession.sendMessage] works
  /// optimistically.
  Future<VideSession> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
    String? permissionMode,
    String? team,
    List<VideAttachment>? attachments,
  });

  /// Resume an existing session by its ID.
  ///
  /// Throws [ArgumentError] if the session is not found.
  Future<VideSession> resumeSession(String sessionId);

  /// List all available sessions.
  ///
  /// Returns session info sorted by most recently active first.
  Future<List<VideSessionInfo>> listSessions();

  /// Delete a session by its ID.
  ///
  /// If the session is currently active, it is disposed first.
  Future<void> deleteSession(String sessionId);

  /// Stream of session list changes (creation, deletion, goal updates).
  ///
  /// Enables reactive UI without polling. Emits the full updated list
  /// whenever a change occurs.
  Stream<List<VideSessionInfo>> get sessionsStream;

  /// Release resources held by this manager.
  void dispose();
}
