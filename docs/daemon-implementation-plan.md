# vide_daemon Implementation Plan

A persistent daemon service that manages multiple vide sessions as sub-processes, with multiple clients (TUI or other) able to connect locally or remotely with full control.

## Requirements

1. **Sub-process isolation**: Each session runs in a separate Dart process
2. **Multi-client support**: Multiple TUIs can connect to the same session
3. **Full client control**: Any connected client can send messages, handle permissions, stop sessions
4. **Local and remote**: Clients can connect from localhost or over network
5. **Session lifecycle**: Create, list, connect, stop sessions

---

## 1. Package Structure

### New Package: `packages/vide_daemon/`

```
packages/vide_daemon/
├── pubspec.yaml
├── bin/
│   └── vide_daemon.dart              # Daemon entry point
├── lib/
│   ├── vide_daemon.dart              # Public exports
│   └── src/
│       ├── daemon/
│       │   ├── daemon_server.dart    # HTTP/WS server for daemon control
│       │   ├── session_registry.dart # Tracks all session processes
│       │   └── session_process.dart  # Manages a single session process
│       ├── protocol/
│       │   ├── daemon_messages.dart  # Daemon ↔ client protocol
│       │   └── daemon_events.dart    # Events from daemon to clients
│       └── client/
│           └── daemon_client.dart    # Client library for TUI/others
└── test/
    └── daemon_test.dart
```

### Updated Package: `lib/` (TUI)

```
lib/
├── modules/
│   └── remote/
│       ├── remote_session_adapter.dart  # Adapts remote WebSocket to local providers
│       ├── remote_agent_network_manager.dart
│       ├── remote_permission_handler.dart
│       └── session_picker_page.dart     # UI to list/select sessions
```

---

## 2. Daemon Core Architecture

### Key Insight: Direct Connection to Session Process

After creating or listing sessions via daemon, clients connect **directly** to the session process WebSocket. The daemon only handles orchestration, not the data plane.

```
1. TUI → Daemon: POST /sessions (create) or GET /sessions (list)
2. Daemon → TUI: { sessionId, wsUrl: "ws://127.0.0.1:PORT/api/v1/sessions/ID/stream" }
3. TUI → Session Process: WebSocket connect to wsUrl (direct)
4. All subsequent communication is TUI ↔ Session Process (daemon not involved)
```

Benefits:
- No proxy overhead
- Session process handles reconnection/history natively
- Multiple clients can connect to same session independently
- Daemon only handles orchestration

### Key Classes

#### `SessionRegistry` (`lib/src/daemon/session_registry.dart`)

```dart
/// Tracks all active session processes managed by the daemon.
class SessionRegistry {
  /// Active sessions by session ID
  final Map<String, SessionProcess> _sessions = {};

  /// Path to state file for persistence
  final String stateFilePath;

  SessionRegistry({required this.stateFilePath});

  /// Create a new session process
  Future<SessionProcess> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,
    String? permissionMode,
  });

  /// List all active sessions
  List<SessionInfo> listSessions();

  /// Get session by ID
  SessionProcess? getSession(String sessionId);

  /// Stop and remove a session
  Future<void> stopSession(String sessionId);

  /// Restore sessions after daemon restart
  Future<void> restore();

  /// Persist current state
  Future<void> persist();

  /// Check health of all sessions
  Future<List<HealthCheckResult>> checkHealth();
}
```

#### `SessionProcess` (`lib/src/daemon/session_process.dart`)

```dart
/// Manages a single vide_server subprocess.
class SessionProcess {
  final String sessionId;
  final String workingDirectory;
  final int port;
  final Process _process;
  final DateTime createdAt;

  /// Process state
  SessionProcessState state = SessionProcessState.starting;

  /// Connected client count (for session sharing)
  int connectedClients = 0;

  /// Check if the process is still running
  bool get isAlive;

  /// Get the WebSocket URL for this session
  String get wsUrl => 'ws://127.0.0.1:$port/api/v1/sessions/$sessionId/stream';

  /// Get the HTTP URL for this session
  String get httpUrl => 'http://127.0.0.1:$port';

  /// Gracefully stop the process
  Future<void> stop();

  /// Force kill the process
  Future<void> kill();
}

enum SessionProcessState {
  starting,  // Process spawned, waiting for ready
  ready,     // Health check passed, accepting connections
  error,     // Process crashed or health check failed
  stopping,  // Graceful shutdown in progress
}
```

#### `DaemonServer` (`lib/src/daemon/daemon_server.dart`)

```dart
/// HTTP/WebSocket server for daemon control and session discovery.
class DaemonServer {
  final SessionRegistry registry;
  final int port;
  final String? authToken;  // Optional token for security

  late HttpServer _server;

  /// Start the daemon server
  Future<void> start();

  /// Stop the daemon server
  Future<void> stop();
}
```

**HTTP Endpoints:**
- `GET  /health` - Daemon health
- `POST /sessions` - Create session (returns session info + WS URL)
- `GET  /sessions` - List all sessions
- `GET  /sessions/:id` - Get session details
- `DELETE /sessions/:id` - Stop a session

**WebSocket Endpoint:**
- `WS /daemon` - Real-time daemon events (session spawn/stop/health)

---

## 3. Protocol Design

### HTTP Requests/Responses (`lib/src/protocol/daemon_messages.dart`)

```dart
// POST /sessions request
class CreateSessionRequest {
  final String initialMessage;
  final String workingDirectory;
  final String? model;
  final String? permissionMode;
  final String? team;
}

// POST /sessions response
class CreateSessionResponse {
  final String sessionId;
  final String mainAgentId;
  final String wsUrl;           // Direct WebSocket URL to session process
  final String httpUrl;         // Direct HTTP URL to session process
  final int port;               // Port the session is running on
  final DateTime createdAt;
}

// GET /sessions response
class ListSessionsResponse {
  final List<SessionSummary> sessions;
}

class SessionSummary {
  final String sessionId;
  final String workingDirectory;
  final String goal;            // Task name
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final int agentCount;
  final SessionProcessState state;
  final int connectedClients;
}

// GET /sessions/:id response
class SessionDetailsResponse {
  final String sessionId;
  final String workingDirectory;
  final String goal;
  final String wsUrl;
  final String httpUrl;
  final int port;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final List<AgentInfo> agents;
  final SessionProcessState state;
  final int connectedClients;
}
```

### WebSocket Events (`lib/src/protocol/daemon_events.dart`)

```dart
// Real-time daemon events (on /daemon WebSocket)
sealed class DaemonEvent {
  String get type;
}

class SessionCreatedEvent implements DaemonEvent {
  final String type = 'session-created';
  final String sessionId;
  final String workingDirectory;
  final String wsUrl;
  final int port;
}

class SessionStoppedEvent implements DaemonEvent {
  final String type = 'session-stopped';
  final String sessionId;
  final String? reason;  // 'user-request', 'crash', 'health-check-failed'
}

class SessionHealthEvent implements DaemonEvent {
  final String type = 'session-health';
  final String sessionId;
  final SessionProcessState state;
  final String? error;
}
```

---

## 4. TUI Changes for `--connect` Mode

### Session Mode Setting

**File: `.claude/settings.local.json`** (or global `~/.vide/settings.json`)

```json
{
  "sessionMode": "local",  // or "daemon"
  "daemon": {
    "address": "localhost:8080",
    "autoStart": true,
    "authToken": null
  }
}
```

**Session Modes:**
- `"local"` (default): Sessions run in-process (current behavior)
- `"daemon"`: Sessions are created in the daemon, TUI connects to them

**When `sessionMode: "daemon"`:**
1. TUI checks if daemon is running at configured address
2. If `autoStart: true` and daemon not running, start it automatically
3. Create session in daemon via `POST /sessions`
4. Connect to returned `wsUrl` for the session
5. User experience is identical to local mode

**Daemon auto-start:**
```dart
// On TUI startup with sessionMode: "daemon"
if (!await _isDaemonRunning(daemonAddress)) {
  if (settings.daemon.autoStart) {
    await _startDaemon(daemonAddress);
    await _waitForDaemonReady(daemonAddress);
  } else {
    throw DaemonNotRunningException(daemonAddress);
  }
}
```

### New CLI Flags

```dart
// bin/vide.dart
..addOption(
  'connect',
  abbr: 'c',
  help: 'Connect to a daemon (format: host:port or just port for localhost)',
)
..addOption(
  'session',
  abbr: 's',
  help: 'Connect to a specific session ID (requires --connect)',
)
..addOption(
  'auth-token',
  help: 'Authentication token for remote daemon',
)
..addFlag(
  'local',
  help: 'Force local session mode (ignore daemon setting)',
  negatable: false,
)
..addFlag(
  'daemon',
  help: 'Force daemon session mode',
  negatable: false,
)
```

### Remote Session Adapter (`lib/modules/remote/remote_session_adapter.dart`)

```dart
/// Adapts a remote WebSocket session to local providers.
///
/// This class bridges the gap between:
/// - Remote: WebSocket events from vide_server
/// - Local: Riverpod providers that TUI components expect
class RemoteSessionAdapter {
  final String wsUrl;
  final ProviderContainer container;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  /// The AgentNetwork model rebuilt from WebSocket events
  AgentNetwork? _network;

  /// Connect and start syncing
  Future<void> connect();

  /// Disconnect and clean up
  Future<void> disconnect();

  /// Send a message (wraps WebSocket send)
  void sendMessage(String content);

  /// Respond to permission request
  void respondToPermission(String requestId, {required bool allow});

  /// Abort the current operation
  void abort();

  // Internal: Maps WebSocket events to provider updates
  void _handleEvent(VideEvent event) {
    switch (event) {
      case ConnectedEvent(:final agents):
        // Initialize AgentNetwork from connected event
        // Update agentNetworkManagerProvider state

      case MessageEvent(:final agentId, :final content):
        // Update the conversation for this agent
        // Triggers UI updates via claudeProvider(agentId)

      case AgentSpawnedEvent(:final agentId, :final agentType):
        // Add agent to network
        // Create placeholder ClaudeClient for UI

      case StatusEvent(:final agentId, :final status):
        // Update agentStatusProvider(agentId)

      // ... etc
    }
  }
}
```

### Provider Overrides for Remote Mode

```dart
// lib/main.dart - when in remote mode

if (remoteMode) {
  final adapter = RemoteSessionAdapter(
    wsUrl: remoteWsUrl,
    container: container,
  );

  // Override providers to use remote adapter
  container = ProviderContainer(
    overrides: [
      // Override the network manager to use remote state
      agentNetworkManagerProvider.overrideWith((ref) {
        return RemoteAgentNetworkManager(adapter: adapter, ref: ref);
      }),

      // ClaudeProvider returns remote-backed clients
      claudeManagerProvider.overrideWith((ref) {
        return adapter.claudeManager;
      }),

      // Permission callback routes to remote
      canUseToolCallbackFactoryProvider.overrideWith((ref) {
        return (ctx) => adapter.createPermissionCallback(ctx);
      }),
    ],
  );

  await adapter.connect();
}
```

---

## 5. Session Lifecycle Flows

### Create Session

```
Client                          Daemon                           Session Process
   |                              |                                    |
   |-- POST /sessions ----------->|                                    |
   |                              |-- spawn vide_server process ------>|
   |                              |                                    |
   |                              |<-- process started (PID, port) ----|
   |                              |                                    |
   |                              |-- health check GET /health ------->|
   |                              |<-- 200 OK ------------------------|
   |                              |                                    |
   |<-- { sessionId, wsUrl } -----|                                    |
   |                              |                                    |
   |-- WS connect to wsUrl ---------------------------------------->|
   |                              |                                    |
   |<-- connected event --------------------------------------------|
   |<-- history event ----------------------------------------------|
   |<-- streaming events -------------------------------------------|
```

### List and Connect to Existing Session

```
Client                          Daemon                           Session Process
   |                              |                                    |
   |-- GET /sessions ------------>|                                    |
   |                              |                                    |
   |<-- [SessionSummary, ...] ----|                                    |
   |                              |                                    |
   |-- GET /sessions/:id -------->|                                    |
   |                              |                                    |
   |<-- { wsUrl, ... } -----------|                                    |
   |                              |                                    |
   |-- WS connect to wsUrl ---------------------------------------->|
   |                              |                                    |
   |<-- connected event (with history) ----------------------------|
```

### Stop Session

```
Client                          Daemon                           Session Process
   |                              |                                    |
   |-- DELETE /sessions/:id ----->|                                    |
   |                              |-- SIGTERM ----------------------->|
   |                              |                                    |
   |                              |<-- process exit ------------------|
   |                              |                                    |
   |<-- 200 OK -------------------|                                    |
```

---

## 6. Persistence

### Daemon State File: `~/.vide/daemon/state.json`

```json
{
  "sessions": [
    {
      "sessionId": "uuid-1",
      "port": 54321,
      "workingDirectory": "/path/to/project",
      "createdAt": "2024-01-28T10:00:00Z",
      "pid": 12345
    }
  ]
}
```

**On daemon restart:**
1. Load state.json
2. Check which PIDs are still alive
3. For alive processes: verify health, re-register
4. For dead processes: clean up from state

**Session process persistence:**
Each `vide_server` process maintains its own state:
- Event history (in `SessionEventStore`)
- Agent network state (persisted via `AgentNetworkPersistenceManager`)

---

## 7. Security (Basic)

### Authentication Token

```dart
// Daemon startup
final authToken = Platform.environment['VIDE_DAEMON_TOKEN']
    ?? _generateRandomToken();

// HTTP header required for all requests
Authorization: Bearer <token>

// Or query parameter for WebSocket
ws://host:port/api/v1/sessions/ID/stream?token=<token>
```

### Network Binding

- **Local only (default)**: Bind to `127.0.0.1`
- **Remote (opt-in)**: Bind to `0.0.0.0` with `--bind-all` flag + require token

---

## 8. Error Handling

### Process Crashes

```dart
// SessionProcess monitors its child process
_process.exitCode.then((code) {
  if (state != SessionProcessState.stopping) {
    // Unexpected crash
    state = SessionProcessState.error;
    _registry.notifySessionCrashed(sessionId, exitCode: code);

    // Optionally restart based on policy
    if (autoRestart && restartCount < maxRestarts) {
      _restart();
    }
  }
});
```

### Connection Drops (Client Side)

```dart
// RemoteSessionAdapter handles reconnection
_channel.stream.handleError((error) {
  _scheduleReconnect();
});

void _scheduleReconnect() {
  Timer(Duration(seconds: _backoff.next()), () async {
    try {
      await connect();
      _backoff.reset();
    } catch (e) {
      _scheduleReconnect();  // Retry with backoff
    }
  });
}
```

### Health Check Failures

```dart
// Daemon periodically checks session health
Timer.periodic(Duration(seconds: 30), (_) async {
  for (final session in _sessions.values) {
    try {
      final response = await http.get(
        Uri.parse('${session.httpUrl}/health'),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        session.state = SessionProcessState.error;
        _notifyClients(SessionHealthEvent(...));
      }
    } catch (e) {
      session.state = SessionProcessState.error;
    }
  }
});
```

---

## 9. Implementation Phases

### Phase 1: Daemon Core (Foundation)

**Goal:** Daemon can spawn and track session processes

**Tasks:**
1. Create `packages/vide_daemon/` package structure
2. Implement `SessionProcess` - spawn vide_server, track PID/port
3. Implement `SessionRegistry` - CRUD operations for sessions
4. Implement `DaemonServer` - HTTP endpoints only
5. Add state persistence (`~/.vide/daemon/state.json`)
6. Add CLI entry point with basic args

**Files:**
- `packages/vide_daemon/pubspec.yaml`
- `packages/vide_daemon/bin/vide_daemon.dart`
- `packages/vide_daemon/lib/src/daemon/session_process.dart`
- `packages/vide_daemon/lib/src/daemon/session_registry.dart`
- `packages/vide_daemon/lib/src/daemon/daemon_server.dart`
- `packages/vide_daemon/lib/src/protocol/daemon_messages.dart`

**Deliverable:** Can run `vide_daemon`, create sessions via curl, see them listed

---

### Phase 2: Client Library & Health Monitoring

**Goal:** Complete daemon functionality with health checks and client lib

**Tasks:**
1. Implement `DaemonClient` for programmatic access
2. Add WebSocket endpoint for daemon events (`/daemon`)
3. Implement health check loop
4. Add daemon restart recovery (load state, verify processes)
5. Add session cleanup (stop, kill commands)
6. Add tests for daemon core

**Files:**
- `packages/vide_daemon/lib/src/client/daemon_client.dart`
- `packages/vide_daemon/lib/src/protocol/daemon_events.dart`
- `packages/vide_daemon/test/daemon_test.dart`

**Deliverable:** Robust daemon with health monitoring and client library

---

### Phase 3: TUI Remote Mode Foundation

**Goal:** TUI can connect to daemon and list/select sessions

**Tasks:**
1. Add `--connect`, `--local`, `--daemon` flags to TUI
2. Add `sessionMode` setting to settings schema
3. Implement daemon auto-start logic
4. Implement `DaemonClient` usage in TUI startup
5. Create session picker UI (list sessions from daemon)
6. Add "Connect to Daemon" option in home page

**Files:**
- `bin/vide.dart` (update args)
- `lib/modules/settings/` (add sessionMode setting)
- `lib/modules/remote/daemon_connection.dart`
- `lib/modules/remote/session_picker_page.dart`

**Deliverable:** TUI can connect to daemon (manually or via setting) and show available sessions

---

### Phase 4: Remote Session Adapter

**Goal:** TUI can control remote sessions with full functionality

**Tasks:**
1. Implement `RemoteSessionAdapter` - WebSocket to provider bridge
2. Create `RemoteAgentNetworkManager` - remote-backed network state
3. Wire up remote permission handling
4. Handle reconnection and error states
5. Ensure UI components work unchanged (they read from providers)

**Files:**
- `lib/modules/remote/remote_session_adapter.dart`
- `lib/modules/remote/remote_agent_network_manager.dart`
- `lib/modules/remote/remote_permission_handler.dart`

**Deliverable:** Full TUI functionality over remote connection

---

### Phase 5: Multi-Client Support & Polish

**Goal:** Multiple TUIs can connect to same session

**Tasks:**
1. Track connected client count per session
2. Test multiple clients sending messages
3. Handle permission conflicts (first responder wins)
4. Add "who else is connected" indicator
5. Add session handoff/takeover semantics

**Deliverable:** Robust multi-client support

---

### Phase 6: Security & Production Readiness

**Goal:** Safe for non-localhost use

**Tasks:**
1. Implement token-based auth
2. Add `--bind-all` flag with required token
3. Document security model
4. Add rate limiting
5. Add comprehensive logging

**Deliverable:** Production-ready daemon

---

## 10. Summary

| Component | Effort | Dependencies |
|-----------|--------|--------------|
| Phase 1: Daemon Core | ~3-4 days | None |
| Phase 2: Client Lib & Health | ~2-3 days | Phase 1 |
| Phase 3: TUI Remote Foundation | ~2-3 days | Phase 2 |
| Phase 4: Remote Session Adapter | ~3-4 days | Phase 3 |
| Phase 5: Multi-Client | ~2 days | Phase 4 |
| Phase 6: Security | ~2 days | Phase 5 |

**Total: ~15-18 days of focused work**

Key architectural decisions:
- **Sub-process per session** for isolation and crash recovery
- **Direct WebSocket connections** from client to session process (daemon only orchestrates)
- **Provider adapter pattern** lets TUI work unchanged over remote connection
- **Phased implementation** delivers value incrementally
