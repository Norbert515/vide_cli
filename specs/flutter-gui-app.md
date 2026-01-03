# Vide Flutter GUI Application Specification

## 1. Executive Summary

### Project Overview
**vide_flutter** is a Flutter-based graphical user interface for the Vide AI coding assistant. It provides a web-first (then desktop/mobile) GUI that connects to the `vide_server` REST API, offering a rich visual experience for multi-agent AI-assisted development.

### Target Platforms
1. **Web** (primary) - Chrome, Firefox, Safari, Edge
2. **Desktop** (secondary) - macOS, Windows, Linux via Flutter desktop
3. **Mobile** (tertiary) - iOS, Android for monitoring/light interaction

### Technology Stack
- **Framework**: Flutter 3.24+
- **State Management**: Riverpod v3 (flutter_riverpod)
- **Navigation**: go_router v14+
- **Chat UI**: dartantic_chat (from dartantic monorepo)
- **HTTP Client**: dio v5+
- **WebSocket Streaming**: web_socket_channel for real-time events
- **Code Highlighting**: flutter_highlight or highlight
- **Diff Rendering**: Custom widget based on diff_match_patch

### Key Constraints
- vide_flutter does **NOT** depend on vide_core (server-side only)
- vide_flutter **ONLY** communicates via REST API and WebSocket endpoints
- State management mirrors vide_core concepts but implemented independently
- Uses dartantic_chat package for chat UI (external dependency from dartantic monorepo)
- Must provide custom widgets for tool visualization (diffs, terminal, etc.)

---

## 2. Architecture Overview

### Package Structure
```
vide_cli/
├── packages/
│   ├── vide_flutter/           # NEW: Flutter GUI application
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── app.dart
│   │   │   ├── core/           # Core utilities and config
│   │   │   ├── data/           # Data layer (API client, models)
│   │   │   ├── domain/         # Business logic abstractions
│   │   │   ├── presentation/   # UI (pages, widgets)
│   │   │   └── providers/      # Riverpod providers
│   │   ├── web/
│   │   ├── test/
│   │   └── pubspec.yaml
│   ├── vide_core/              # Server-side shared logic
│   ├── vide_server/            # REST API server
│   └── ...
```

**Rationale**: Placing vide_flutter in `packages/` keeps it alongside vide_server, making the monorepo structure clear. The app uses dartantic_chat as an external dependency for chat UI functionality.

### Layer Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐│
│  │   Pages     │ │  Widgets    │ │  dartantic_chat         ││
│  │  (Screens)  │ │ (Components)│ │  (Chat UI + Custom)     ││
│  └─────────────┘ └─────────────┘ └─────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Riverpod Providers (State)                 ││
│  │  sessionProvider, agentProvider, chatProvider, etc.     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐│
│  │   Models    │ │ Repositories│ │ ChatHistoryProvider     ││
│  │  (Session,  │ │ (Interfaces)│ │  (Custom) for           ││
│  │   Agent)    │ │             │ │                         ││
│  └─────────────┘ └─────────────┘ └─────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  VideApiClient (dio + WebSocket)        ││
│  │  - REST: POST /api/v1/sessions (create session)         ││
│  │  - WebSocket: ws://.../api/v1/sessions/{id}/stream      ││
│  │  - Bidirectional: server events + client messages       ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  vide_server    │
                    │  (REST API)     │
                    └─────────────────┘
```

### Dependency Flow
- Presentation → Application (providers) → Domain → Data
- No circular dependencies
- Data layer is the only layer that knows about HTTP/REST

### State Management Strategy (Riverpod v3)
- **AsyncNotifierProvider** for async state (session creation, message sending)
- **StreamProvider** for WebSocket event streams
- **StateProvider** for simple UI state (selected session, theme)
- **Provider** for computed/derived state

### Navigation (go_router)
- Declarative routing with typed routes
- Deep linking support for web
- Shell route for persistent sidebar/navigation

---

## 2.5 Prerequisites (vide_server) - ✅ COMPLETE

The following vide_server features have been implemented and are ready for vide_flutter development:

### Multiplexed WebSocket Streaming ✅
- Single WebSocket endpoint per session: `ws://.../api/v1/sessions/{session-id}/stream`
- All agent events (main + spawned agents) multiplexed on this single stream
- Each event includes:
  - `seq` - sequence number for ordering/deduplication
  - `event-id` - UUID shared across partial chunks for accumulation
  - Attribution fields: `agent-id`, `agent-type`, `agent-name`, `task-name`
  - `timestamp` - when event occurred
- Client receives unified timeline without managing multiple WebSocket connections
- Server does NOT accumulate message content - sends each chunk as received
- Client is responsible for accumulating chunks with matching `event-id`

### Bidirectional WebSocket ✅
- WebSocket is fully bidirectional: server sends events, client sends messages and commands
- All session messages sent via WebSocket (no HTTP POST for messages after session creation)

**Permission requests** (server → client):
```json
{
  "seq": 8,
  "event-id": "770e8400-e29b-41d4-a716-446655440008",
  "type": "permission-request",
  "agent-id": "550e8400-e29b-41d4-a716-446655440000",
  "agent-type": "implementation",
  "agent-name": "Auth Fix",
  "task-name": "Implementing login flow",
  "timestamp": "2025-12-21T10:00:00Z",
  "data": {
    "request-id": "660e8400-e29b-41d4-a716-446655440001",
    "tool-name": "Bash",
    "tool-input": {"command": "rm -rf node_modules"},
    "permission-suggestions": ["Bash(rm *)"]
  }
}
```

**Client responds** via WebSocket message:
```json
{
  "type": "permission-response",
  "request-id": "660e8400-e29b-41d4-a716-446655440001",
  "allow": true
}
```

Or deny with optional message:
```json
{
  "type": "permission-response",
  "request-id": "660e8400-e29b-41d4-a716-446655440001",
  "allow": false,
  "message": "User declined"
}
```

- Server blocks agent execution until client responds or times out (60s default)
- On timeout, server auto-denies and sends `permission-timeout` event

### Model Selection Support ✅
- Model selection via `user-message` WebSocket event (not HTTP POST)
- Valid values: `"sonnet"` (default), `"opus"`, `"haiku"`
- Model selection applies per-message, allowing users to switch mid-conversation

### WebSocket Keepalive & Reconnection ⬜ (Pending)
- **Protocol-level ping/pong**: The `web_socket_channel` package handles WebSocket ping/pong frames automatically at the protocol level. No application code needed.
- **Application-level heartbeat** (optional): For additional reliability, clients may send periodic lightweight messages (e.g., every 30s) to detect dead connections faster than TCP timeout.
- **Reconnection with exponential backoff**: The most critical component. When connection drops:
  1. Attempt reconnect with exponential backoff (e.g., 1s, 2s, 4s, 8s... capped at 30s)
  2. On successful reconnect, receive `connected` event with `last-seq`
  3. Receive `history` event with all session events
  4. Deduplicate by comparing `event.seq` against tracked `last-seq`
  5. Resume normal event processing
- **State recovery**: The `seq` field on all events enables reliable ordering and deduplication. Clients should track the highest `seq` seen and ignore events with `seq <= lastSeq` on reconnect.

### Filesystem Browsing API ⬜ (In Progress)
- `GET /api/v1/filesystem?parent=...` endpoint for hierarchical directory listing
  - `parent` parameter: path to list children of; `null`/omitted = server-configured root
  - Returns entries: `{ "name", "path", "is-directory" }` for both files and folders
- `POST /api/v1/filesystem` endpoint for creating new folders
  - Body: `{ "parent": "...", "name": "..." }`
  - Creates folder at `parent/name`; `parent` must be within server root
  - Returns: `{ "path": "..." }` of created folder
- Root directory configured via server config file (`~/.vide/api/config.json`)
- Server enforces a configurable root directory (prevents access outside allowed scope)
- **Symlinks are NOT followed** to prevent escaping the configured filesystem root
- **Client behavior for folder selection:**
  - Filters results to show folders only
  - Caches directory listings for the duration of the browsing session
  - Supports progressive expansion (load children on demand)
  - Allows creating new project folders before selection
- **Future use:** Enables file explorer panel with full file/folder tree

---

## 3. Phase Breakdown

### Phase 1: MVP Core Chat (~2-3 days)

#### Features
- [ ] Connect to vide_server (configurable URL)
- [ ] Create new session with initial message
- [ ] Send messages to session via WebSocket
- [ ] Stream WebSocket responses and display in chat
- [ ] Basic markdown rendering in responses
- [ ] Server URL configuration (localhost default)
- [ ] Working directory browser (server filesystem API)

#### Screens/Pages
1. **HomePage** - Server connection + session list
2. **ChatPage** - Main chat interface with dartantic_chat

#### Widgets/Components
- `ServerConfigDialog` - Configure server URL
- `FolderBrowserDialog` - Browse and select working directory from server filesystem
- `SessionListTile` - Display session in list
- `ChatView` - dartantic_chat AgentChatView wrapper
- `MessageBubble` - Basic message display

#### API Integration
- `POST /api/v1/sessions` - Create session (returns `session-id`, `main-agent-id`)
- `ws://.../api/v1/sessions/{session-id}/stream` - Bidirectional WebSocket (all agents multiplexed)
  - Send messages via `user-message` WebSocket event
  - Receive events: `connected`, `history`, `status`, `message`, `tool-use`, `tool-result`, `done`, `error`
- `GET /api/v1/filesystem?parent=...` - List directory contents

#### Success Criteria
- Can connect to localhost vide_server
- Can create session and see response
- Can send follow-up messages via WebSocket
- Real-time streaming works

---

### Phase 2: Tool Visualization & Agent Management (~3-4 days)

#### Features
- [ ] Custom response widgets for tool calls
- [ ] Code diff visualization (syntax highlighted)
- [ ] Terminal output rendering
- [ ] File tree visualization
- [ ] Todo list rendering
- [ ] Agent status indicators (working/waitingForAgent/waitingForUser/idle)
- [ ] Unified timeline with multi-agent activity (all agents interleaved with attribution)

#### Screens/Pages
- Enhanced ChatPage with tool visualizations

#### Widgets/Components
- `DiffWidget` - Side-by-side or unified diff view
- `TerminalWidget` - Terminal-style output
- `FileTreeWidget` - File/folder structure
- `TodoListWidget` - Checkable todo items
- `AgentStatusIndicator` - Status badge (working/waitingForAgent/waitingForUser/idle)
- `AgentAttributionBadge` - Shows which agent sent a message in unified timeline
- `ToolCallCard` - Generic tool call wrapper

#### API Integration
- Parse WebSocket events by type (all use kebab-case):
  - `connected` - session metadata on connect
  - `history` - all events for reconnection/state recovery
  - `status` - agent status changes (working, waiting-for-agent, waiting-for-user, idle)
  - `message` - streaming text with `is-partial` flag and `event-id` for accumulation
  - `tool-use` - agent invoking a tool
  - `tool-result` - tool execution result
  - `agent-spawned` - new agent added to session
  - `agent-terminated` - agent removed from session
  - `permission-request` - tool needs user approval
  - `done` - agent turn complete
  - `error` - error occurred
- Handle multiplexed agent events (different `agent-id` in stream)
- Correlate tool calls with results via `tool-use-id`
- Accumulate `message` chunks with same `event-id` until `is-partial: false`

#### Success Criteria
- Tool calls render with appropriate visualization
- Can see which agent is active
- Code diffs are syntax highlighted
- Terminal output looks authentic

---

### Phase 3: Advanced Features (~2-3 days)

#### Features
- [ ] Session history and persistence (local storage)
- [ ] Resume previous sessions
- [ ] Permission mode UI (surfaces tool approval requests from WebSocket stream)
- [ ] Model selection dropdown (Sonnet, Opus, Haiku - set per-message)
- [ ] Memory viewer (read-only)
- [ ] Settings page (theme, server URL, preferences)
- [ ] Responsive design (mobile-friendly)

#### Screens/Pages
1. **HistoryPage** - List of past sessions
2. **SettingsPage** - App configuration
3. **MemoryViewerPage** - View agent memories

#### Widgets/Components
- `ToolApprovalDialog` - Displays pending tool calls requiring user approval
- `ModelDropdown` - Model selection (Sonnet/Opus/Haiku, persisted per-session, applied per-message)
- `MemoryEntryCard` - Display memory entry
- `SessionHistoryList` - Searchable history
- `ThemeToggle` - Light/dark mode

#### API Integration
- `GET /api/v1/sessions` - List sessions (future server endpoint)
- `GET /api/v1/sessions/:id` - Get session details (future)
- `GET /api/v1/sessions/:id/memory` - Get memories (future)

#### Success Criteria
- Can browse session history
- Tool approval requests display and user can approve/deny
- Responsive on mobile viewport
- Settings persist across sessions

---

### Phase 4: Polish & Enhancement (~2-3 days)

#### Features
- [ ] Keyboard shortcuts
- [ ] Copy code/diff buttons
- [ ] Syntax highlighting theme options
- [ ] Loading states and skeletons
- [ ] Error handling and retry UI
- [ ] Offline detection
- [ ] Performance optimization (lazy loading, virtualization)
- [ ] Accessibility (screen reader, high contrast)

#### Widgets/Components
- `CopyButton` - Copy to clipboard
- `LoadingSkeleton` - Shimmer loading states
- `ErrorBanner` - Dismissible error display
- `OfflineIndicator` - Connection status
- `KeyboardShortcutsHelp` - Shortcut reference

#### Success Criteria
- Smooth 60fps scrolling
- All actions have loading feedback
- Errors are recoverable
- Accessible via keyboard

---

## 4. Custom dartantic_chat Provider Design

### JSON Event Accumulation Model

The server sends raw WebSocket events as partial chunks. The **client** is responsible for accumulating these into a JSON structure stored in `ChatMessage.text`. The `responseBuilder` parses this JSON to render rich Flutter widgets.

**Event accumulation flow (client-side):**
1. WebSocket receives `message` with `is-partial: true` → Append text to current text event in JSON (use `event-id` to correlate chunks)
2. WebSocket receives `message` with `is-partial: false` → Finalize current message
3. WebSocket receives `tool-use` → Append tool call event to JSON
4. WebSocket receives `tool-result` → Append tool result event to JSON
5. On each update, `responseBuilder` re-parses the JSON and renders widgets

**Important**: The server does NOT accumulate message content - it sends each chunk as received. The client must accumulate chunks with matching `event-id`. All events include `seq` for ordering and deduplication on reconnect.

**ChatMessage.text JSON structure:**
```json
{
  "events": [
    {"type": "text", "content": "Let me help you with that."},
    {"type": "tool-call", "call-id": "123", "name": "Bash", "args": {"command": "ls -la"}},
    {"type": "tool-result", "call-id": "123", "result": "file1.txt\nfile2.txt", "is-error": false},
    {"type": "text", "content": "Here are your files."}
  ]
}
```

**Accumulation helper:**
```dart
String accumulateEvent(String currentText, Map<String, dynamic> newEvent) {
  final current = currentText.isEmpty
      ? {'events': <dynamic>[]}
      : jsonDecode(currentText) as Map<String, dynamic>;
  final events = current['events'] as List<dynamic>;
  events.add(newEvent);
  return jsonEncode(current);
}
```

**responseBuilder parsing:**
```dart
responseBuilder: (context, response) {
  final json = jsonDecode(response) as Map<String, dynamic>;
  final events = json['events'] as List<dynamic>;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final event in events)
        _buildEventWidget(event as Map<String, dynamic>),
    ],
  );
}

Widget _buildEventWidget(Map<String, dynamic> event) {
  return switch (event['type']) {
    'text' => MarkdownBody(data: event['content'] as String),
    'tool-call' => ToolCallWidget(
      callId: event['call-id'] as String,
      name: event['name'] as String,
      args: event['args'] as Map<String, dynamic>,
    ),
    'tool-result' => ToolResultWidget(
      callId: event['call-id'] as String,
      result: event['result'] as String,
      isError: event['is-error'] as bool? ?? false,
    ),
    _ => const SizedBox.shrink(),
  };
}
```

This approach allows the UI to update incrementally as events stream in, providing a rich, real-time experience.

### ChatHistoryProvider Implementation

The dartantic_chat package requires implementing the `ChatHistoryProvider` interface to connect to custom backends. Our implementation uses WebSocket for real-time streaming.

```dart
// lib/domain/vide_chat_history_provider.dart

import 'package:dartantic_chat/dartantic_chat.dart';

class VideChatHistoryProvider implements ChatHistoryProvider {
  final String _sessionId;
  final WebSocketClient _wsClient;

  // Internal message history (provider manages this)
  final List<ChatMessage> _history = [];

  // Accumulated text for current response (built from partial chunks)
  String _currentResponseText = '';

  // Current event-id for accumulating partial message chunks
  String? _currentEventId;

  // Current agent context (for multi-agent timeline attribution)
  String? _currentAgentId;
  String? _currentAgentType;
  String? _currentAgentName;

  VideChatHistoryProvider({
    required String sessionId,
    required WebSocketClient wsClient,
  }) : _sessionId = sessionId,
       _wsClient = wsClient;

  @override
  Stream<String> sendMessageStream(String message) async* {
    // 1. Add user message to history
    _history.add(ChatMessage.user(message));
    _currentResponseText = '';
    _currentEventId = null;

    // 2. Send message via WebSocket (not HTTP POST)
    _wsClient.sendMessage({
      'type': 'user-message',
      'content': message,
    });

    // 3. Listen to WebSocket stream for events
    await for (final event in _wsClient.events) {
      // Track current agent for multi-agent timeline attribution
      _currentAgentId = event.agentId;
      _currentAgentType = event.agentType;
      _currentAgentName = event.agentName;

      switch (event.type) {
        case 'message':
          // Streaming message chunk - accumulate using event-id
          final content = event.data['content'] as String?;
          final eventId = event.eventId;
          final isPartial = event.isPartial;

          if (content != null) {
            // If new event-id, start fresh accumulation
            if (_currentEventId != eventId) {
              _currentEventId = eventId;
              _currentResponseText = content;
            } else {
              // Same event-id, append to accumulated text
              _currentResponseText += content;
            }
            yield _currentResponseText;
          }

          // If is-partial is false, message is complete
          if (!isPartial) {
            _currentEventId = null;
          }
        case 'done':
          // Turn complete - finalize history with agent attribution
          _history.add(ChatMessage(
            role: ChatMessageRole.model,
            parts: [TextPart(_currentResponseText)],
            metadata: {
              'agent-id': _currentAgentId,
              'agent-type': _currentAgentType,
              'agent-name': _currentAgentName,
            },
          ));
          return;
        case 'error':
          throw Exception(event.data['message'] as String? ?? 'Unknown error');
        // tool-use and tool-result handled via responseBuilder
      }
    }
  }

  @override
  List<ChatMessage> get history => List.unmodifiable(_history);

  @override
  void clearHistory() {
    _history.clear();
  }
}
```

### WebSocket Client

```dart
// lib/data/api/websocket_client.dart

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();

  Stream<WebSocketEvent> get events => _eventController.stream;

  /// Connect to the WebSocket stream for a session
  Future<void> connect(String wsUrl) async {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _eventController.add(WebSocketEvent.fromJson(json));
      },
      onError: (error) {
        _eventController.addError(error);
      },
      onDone: () {
        _eventController.close();
      },
    );
  }

  /// Send a message to the server (bidirectional WebSocket)
  void sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
```

### Custom Response Widgets

dartantic_chat supports custom response widgets via `responseBuilder`:

```dart
// lib/presentation/widgets/chat/vide_chat_view.dart

AgentChatView(
  provider: videChatHistoryProvider,
  responseBuilder: (context, message) {
    // Access agent metadata for multi-agent timeline attribution
    final agentId = message.metadata?['agent-id'] as String?;
    final agentType = message.metadata?['agent-type'] as String?;
    final agentName = message.metadata?['agent-name'] as String?;

    // Parse response for tool calls
    final toolCalls = _parseToolCalls(message);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show agent attribution badge for multi-agent timeline
        if (agentType != null)
          AgentAttributionBadge(
            agentId: agentId!,
            agentType: agentType,
            agentName: agentName,
          ),
        // Message content
        if (toolCalls.isEmpty)
          MarkdownBody(data: message.text)
        else ...[
          if (message.textBeforeTools.isNotEmpty)
            MarkdownBody(data: message.textBeforeTools),
          for (final tool in toolCalls)
            _buildToolWidget(tool),
          if (message.textAfterTools.isNotEmpty)
            MarkdownBody(data: message.textAfterTools),
        ],
      ],
    );
  },
)

Widget _buildToolWidget(ToolCall tool) {
  return switch (tool.name) {
    'Write' || 'Edit' => DiffWidget(tool: tool),
    'Bash' || 'Execute' => TerminalWidget(tool: tool),
    'TodoWrite' => TodoListWidget(tool: tool),
    'Read' || 'Glob' => FileTreeWidget(tool: tool),
    _ => DefaultToolWidget(tool: tool),
  };
}
```

### Integration with WebSocket Events

The provider needs to handle the multiplexed WebSocket event structure. Following the pattern from `vide_server/example`, we use a **sealed class hierarchy** with manual JSON parsing for clean kebab-case → camelCase conversion:

```dart
// lib/data/models/websocket_event.dart

/// Base class for all WebSocket events.
/// See vide_server/example/lib/src/events.dart for reference implementation.
sealed class WebSocketEvent {
  final int? seq;
  final String? eventId;
  final DateTime timestamp;
  final AgentInfo? agent;

  const WebSocketEvent({
    this.seq,
    this.eventId,
    required this.timestamp,
    this.agent,
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final seq = json['seq'] as int?;
    final eventId = json['event-id'] as String?;
    final agent = json['agent-id'] != null ? AgentInfo.fromJson(json) : null;
    final data = json['data'] as Map<String, dynamic>?;

    return switch (type) {
      'connected' => ConnectedEvent(...),
      'history' => HistoryEvent(...),
      'message' => MessageEvent(
          seq: seq,
          eventId: eventId,
          timestamp: timestamp,
          agent: agent,
          role: data?['role'] as String? ?? 'assistant',
          content: data?['content'] as String? ?? '',
          isPartial: json['is-partial'] as bool? ?? false,
        ),
      'status' => StatusEvent(...),
      'tool-use' => ToolUseEvent(...),
      'tool-result' => ToolResultEvent(...),
      'permission-request' => PermissionRequestEvent(...),
      'done' => DoneEvent(...),
      'error' => ErrorEvent(...),
      _ => UnknownEvent(type: type, rawData: json, ...),
    };
  }
}

/// Agent metadata attached to events.
class AgentInfo {
  final String id;
  final String type;      // "main", "implementation", "planning", "context-collection"
  final String name;
  final String? taskName;

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
    id: json['agent-id'] as String? ?? '',
    type: json['agent-type'] as String? ?? '',
    name: json['agent-name'] as String? ?? 'Agent',
    taskName: json['task-name'] as String?,
  );
}

/// Streaming message chunk or complete message.
class MessageEvent extends WebSocketEvent {
  final String role;
  final String content;
  final bool isPartial;
  // ... constructor
}

// See vide_server/example/lib/src/events.dart for complete event class definitions
```

**Event Types** (all use kebab-case):
- `connected` - Initial WebSocket connection with session metadata
- `history` - All session events for reconnection/state recovery
- `status` - Agent status changed (data: `{status: "working" | "waiting-for-agent" | "waiting-for-user" | "idle"}`)
- `message` - Streaming text chunk (data: `{role, content}`) with `is-partial` flag
- `tool-use` - Agent invoking a tool (data: `{tool-name, tool-input, tool-use-id}`)
- `tool-result` - Tool execution result (data: `{tool-name, result, is-error, tool-use-id}`)
- `permission-request` - Tool needs user approval (data: `{request-id, tool-name, ...}`)
- `permission-timeout` - Permission request timed out (auto-denied)
- `agent-spawned` - New agent added to session
- `agent-terminated` - Agent removed from session
- `aborted` - Operation cancelled via abort command
- `done` - Agent turn complete (data: `{reason}`)
- `error` - Error occurred (data: `{message, code}`)

### Multi-Agent Timeline Support

The unified timeline displays messages from all agents (main, implementation, planning, etc.) in chronological order with visual attribution. This is achieved by:

1. **Agent metadata in ChatMessage**: Each message stores `agent-id`, `agent-type`, and `agent-name` in `ChatMessage.metadata`
2. **WebSocket event tracking**: The provider captures agent context from each WebSocket event
3. **Custom responseBuilder**: Uses metadata to render `AgentAttributionBadge` showing which agent sent each message
4. **Visual differentiation**: Different agent types can have distinct colors/icons (e.g., main agent = blue, implementation = green)

```dart
// Agent attribution badge widget
class AgentAttributionBadge extends StatelessWidget {
  final String agentId;
  final String agentType;
  final String? agentName;

  Color get _badgeColor => switch (agentType) {
    'main' => Colors.blue,
    'implementation' => Colors.green,
    'planning' => Colors.purple,
    'context-collection' => Colors.orange,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _badgeColor),
      ),
      child: Text(
        agentName ?? agentType,
        style: TextStyle(color: _badgeColor, fontSize: 12),
      ),
    );
  }
}
```

---

## 5. UI/UX Design

### Screen Layouts

#### Web Layout (Primary)
```
┌─────────────────────────────────────────────────────────────────┐
│  ┌─────────┐  Vide Flutter                        [Settings] ⚙️ │
│  │  Logo   │                                                    │
├──┴─────────┴────────────────────────────────────────────────────┤
│ ┌──────────────┐ ┌────────────────────────────────────────────┐ │
│ │              │ │                                            │ │
│ │   Session    │ │              Chat Area                     │ │
│ │   History    │ │                                            │ │
│ │              │ │  ┌──────────────────────────────────────┐  │ │
│ │  • Session 1 │ │  │ Agent: Thinking...              🟢   │  │ │
│ │  • Session 2 │ │  └──────────────────────────────────────┘  │ │
│ │  • Session 3 │ │                                            │ │
│ │              │ │  [Message bubbles with tool widgets]       │ │
│ │              │ │                                            │ │
│ │              │ │                                            │ │
│ │              │ ├────────────────────────────────────────────┤ │
│ │              │ │                               Model: ▼     │ │
│ │              │ ├────────────────────────────────────────────┤ │
│ │              │ │ [Type your message...              ] [Send]│ │
│ └──────────────┘ └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

#### Mobile Layout (Responsive)
```
┌─────────────────────┐
│ ☰  Vide Flutter  ⚙️ │
├─────────────────────┤
│                     │
│    Chat Area        │
│                     │
│  [Messages...]      │
│                     │
├─────────────────────┤
│              ▼      │
├─────────────────────┤
│ [Message...]  [📤]  │
└─────────────────────┘
```

### Navigation Patterns
- **Web**: Persistent sidebar with session list
- **Mobile**: Hamburger menu with drawer
- **Desktop**: Same as web

### Component Hierarchy
```
App
├── MaterialApp.router (go_router)
├── ProviderScope (Riverpod)
└── ShellRoute
    ├── Scaffold
    │   ├── AppBar
    │   ├── Drawer (mobile) / Sidebar (web)
    │   └── Body
    │       ├── HomePage
    │       ├── ChatPage
    │       │   ├── AgentStatusBar
    │       │   ├── ChatMessageList
    │       │   │   └── MessageBubble
    │       │   │       ├── MarkdownContent
    │       │   │       └── ToolWidgets
    │       │   ├── ToolApprovalDialog (modal, shown when approval needed)
    │       │   └── MessageInput
    │       ├── HistoryPage
    │       └── SettingsPage
    └── NavigationRail (web/desktop)
```

### Material Design 3 Theming
```dart
// lib/core/theme/app_theme.dart

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.light,
  ),
  // Custom component themes
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.dark,
  ),
);
```

---

## 6. Data Layer

### REST API Client

```dart
// lib/data/api/vide_api_client.dart

class VideApiClient {
  final Dio _dio;
  final String _baseUrl;

  VideApiClient({required String baseUrl})
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(baseUrl: baseUrl));

  /// Create a new session
  /// Returns session-id and main-agent-id for immediate WebSocket connection
  Future<CreateSessionResponse> createSession({
    required String initialMessage,
    required String workingDirectory,
    String? model,           // optional: "sonnet" (default), "opus", "haiku"
    String? permissionMode,  // optional: "accept-edits" (default), "plan", "ask", "deny"
  }) async {
    final response = await _dio.post('/api/v1/sessions', data: {
      'initial-message': initialMessage,
      'working-directory': workingDirectory,
      if (model != null) 'model': model,
      if (permissionMode != null) 'permission-mode': permissionMode,
    });
    return CreateSessionResponse.fromJson(response.data);
  }

  // NOTE: Messages are sent via WebSocket, not HTTP POST
  // Use WebSocketClient.sendMessage({'type': 'user-message', 'content': '...'})

  /// List directory contents for folder browser
  /// [parent] - path to list children of; null = server root
  Future<List<DirectoryEntry>> listDirectory({String? parent}) async {
    final response = await _dio.get('/api/v1/filesystem', queryParameters: {
      if (parent != null) 'parent': parent,
    });
    return (response.data['entries'] as List)
        .map((e) => DirectoryEntry.fromJson(e))
        .toList();
  }

  /// Create a new folder
  /// [parent] - parent directory path (must be within server root)
  /// [name] - name of the new folder
  /// Returns the full path of the created folder
  Future<String> createFolder({required String parent, required String name}) async {
    final response = await _dio.post('/api/v1/filesystem', data: {
      'parent': parent,
      'name': name,
    });
    return response.data['path'] as String;
  }

  /// Get WebSocket URL for bidirectional streaming (multiplexed, all agents)
  String getWebSocketUrl(String sessionId) {
    final wsBase = _baseUrl.replaceFirst('http', 'ws');
    return '$wsBase/api/v1/sessions/$sessionId/stream';
  }
}
```

### Models

```dart
// lib/data/models/session.dart
@freezed
class Session with _$Session {
  const factory Session({
    required String id,
    required String goal,
    required List<Agent> agents,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    String? workingDirectory,
    String? worktreePath,         // Git worktree path if using worktrees
  }) = _Session;
}

// lib/data/models/create_session_response.dart
@freezed
class CreateSessionResponse with _$CreateSessionResponse {
  const factory CreateSessionResponse({
    @JsonKey(name: 'session-id') required String sessionId,
    @JsonKey(name: 'main-agent-id') required String mainAgentId,
    @JsonKey(name: 'created-at') required DateTime createdAt,
  }) = _CreateSessionResponse;

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionResponseFromJson(json);
}

// lib/data/models/agent.dart
@freezed
class Agent with _$Agent {
  const factory Agent({
    required String id,
    required String type,
    required String name,
    required AgentStatus status,
    String? currentTask,
  }) = _Agent;
}

// lib/data/models/agent_status.dart
// Matches vide_core AgentStatus enum
enum AgentStatus {
  idle,             // Agent finished, not waiting
  working,          // Actively processing
  waitingForAgent,  // Waiting for another agent's response
  waitingForUser,   // Waiting for user input/approval
}

// Note: ChatMessage is defined in the dartantic_interface package.
// Import via: import 'package:dartantic_interface/dartantic_interface.dart';
// The ChatHistoryProvider interface requires ChatMessage, which supports:
// - ChatMessageRole.user, ChatMessageRole.model, ChatMessageRole.system
// - Parts: TextPart, DataPart, LinkPart, ToolPart
// - Metadata map for agent attribution (agent-id, agent-type, agent-name)

// lib/data/models/tool_call.dart
@freezed
class ToolCall with _$ToolCall {
  const factory ToolCall({
    required String id,           // toolUseId for correlation
    required String name,
    required Map<String, dynamic> params,
    ToolResult? result,
  }) = _ToolCall;
}

// lib/data/models/directory_entry.dart
@freezed
class DirectoryEntry with _$DirectoryEntry {
  const factory DirectoryEntry({
    required String name,
    required String path,
    @JsonKey(name: 'is-directory') required bool isDirectory,
  }) = _DirectoryEntry;

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) =>
      _$DirectoryEntryFromJson(json);
}
```

### Caching Strategy
- **Session list**: Cache in Riverpod provider, refresh on demand
- **Messages**: Keep in memory during session, optionally persist to local storage
- **WebSocket events**: Process and discard (not cached)

---

## 7. State Management with Riverpod v3

### Provider Hierarchy

```dart
// lib/providers/config_provider.dart
@riverpod
class ServerConfig extends _$ServerConfig {
  @override
  String build() => 'http://localhost:8080';
  
  void setUrl(String url) => state = url;
}

// lib/providers/api_client_provider.dart
@riverpod
VideApiClient apiClient(ApiClientRef ref) {
  final serverUrl = ref.watch(serverConfigProvider);
  return VideApiClient(baseUrl: serverUrl);
}

// lib/providers/session_provider.dart
@riverpod
class CurrentSession extends _$CurrentSession {
  @override
  AsyncValue<Session?> build() => const AsyncValue.data(null);

  Future<void> createSession(String initialMessage, String workingDir) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.createSession(
        initialMessage: initialMessage,
        workingDirectory: workingDir,
      );
      state = AsyncValue.data(Session(
        id: response.sessionId,
        goal: initialMessage,
        agents: [Agent(id: response.mainAgentId, ...)],
        ...
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// lib/providers/chat_provider.dart
// Note: ChatMessages provider uses ChatMessage from dartantic_interface.
// The VideChatHistoryProvider manages message history internally,
// so this provider is primarily for UI state synchronization.

// lib/providers/websocket_provider.dart
@riverpod
class WebSocketConnection extends _$WebSocketConnection {
  WebSocketClient? _client;

  @override
  Stream<WebSocketEvent> build(String sessionId) async* {
    final api = ref.watch(apiClientProvider);
    final wsUrl = api.getWebSocketUrl(sessionId);

    _client = WebSocketClient();
    await _client!.connect(wsUrl);

    ref.onDispose(() => _client?.disconnect());

    // All agent events are multiplexed on this single stream
    // Client can send messages via _client.sendMessage()
    yield* _client!.events;
  }
}

// lib/providers/agent_status_provider.dart
@riverpod
class AgentStatuses extends _$AgentStatuses {
  @override
  Map<String, AgentStatus> build() => {};

  void updateStatus(String agentId, AgentStatus status) {
    state = {...state, agentId: status};
  }
}
```

### Repository Pattern

```dart
// lib/domain/repositories/session_repository.dart
abstract class SessionRepository {
  Future<Session> createSession(String message, String workingDir);
  Stream<WebSocketEvent> streamEvents(String sessionId);  // Multiplexed stream
  void sendMessage(String sessionId, String content);     // Via WebSocket
}

// lib/data/repositories/session_repository_impl.dart
class SessionRepositoryImpl implements SessionRepository {
  final VideApiClient _apiClient;
  final WebSocketClient _wsClient;

  SessionRepositoryImpl(this._apiClient, this._wsClient);

  @override
  Future<Session> createSession(String message, String workingDir) async {
    final response = await _apiClient.createSession(
      initialMessage: message,
      workingDirectory: workingDir,
    );
    return Session(id: response.sessionId, ...);
  }

  @override
  void sendMessage(String sessionId, String content) {
    _wsClient.sendMessage({
      'type': 'user-message',
      'content': content,
    });
  }

  // ... other methods
}
```

### Error Handling

```dart
// lib/core/errors/app_exception.dart
sealed class AppException implements Exception {
  String get message;
}

class NetworkException extends AppException {
  @override
  final String message;
  final int? statusCode;
  
  NetworkException(this.message, {this.statusCode});
}

class ServerConnectionException extends AppException {
  @override
  String get message => 'Unable to connect to server';
}

// Usage in providers
@riverpod
class CurrentSession extends _$CurrentSession {
  Future<void> createSession(...) async {
    state = const AsyncValue.loading();
    try {
      // ...
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        state = AsyncValue.error(ServerConnectionException(), StackTrace.current);
      } else {
        state = AsyncValue.error(
          NetworkException(e.message ?? 'Unknown error', statusCode: e.response?.statusCode),
          StackTrace.current,
        );
      }
    }
  }
}
```

---

## 8. Key Technical Decisions

### Why Flutter Web First vs. Desktop/Mobile
1. **Immediate accessibility** - No app store approval, works in any browser
2. **Easy deployment** - Static hosting (Vercel, Netlify, Firebase Hosting)
3. **Development speed** - Hot reload works great on web
4. **Target audience** - Developers already at their computers

### State Management Rationale (Riverpod v3)
1. **Compile-time safety** - Code generation catches errors early
2. **Testability** - Easy to override providers in tests
3. **Familiarity** - Same patterns as vide_core (Riverpod consistency)
4. **Performance** - Fine-grained rebuilds, no unnecessary widget rebuilds

### Navigation Approach (go_router)
1. **Flutter official** - Maintained by Flutter team
2. **Deep linking** - Essential for web
3. **Type-safe routes** - Reduces navigation errors
4. **Shell routes** - Perfect for persistent sidebar

### Custom Provider vs. Existing AI Toolkit Providers
1. **WebSocket protocol** - vide_server uses WebSocket for real-time streaming
2. **Multi-agent** - Need to handle multiplexed agent events in unified timeline
3. **Tool visualization** - Custom widgets require custom data flow
4. **Control** - Full control over message history and state
5. **dartantic_chat** - Purpose-built chat UI from dartantic ecosystem

---

## 9. Testing Strategy

### Unit Tests
```dart
// test/providers/session_provider_test.dart
void main() {
  group('CurrentSession', () {
    test('createSession updates state on success', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(MockVideApiClient()),
      ]);

      await container.read(currentSessionProvider.notifier)
        .createSession('Test message', '/path');

      expect(
        container.read(currentSessionProvider),
        isA<AsyncData<Session>>(),
      );
    });
  });
}
```

### Widget Tests
```dart
// test/widgets/diff_widget_test.dart
void main() {
  testWidgets('DiffWidget renders additions and deletions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiffWidget(
        oldContent: 'hello',
        newContent: 'hello world',
      ),
    ));
    
    expect(find.text('+ world'), findsOneWidget);
  });
}
```

### Integration Tests
```dart
// integration_test/chat_flow_test.dart
void main() {
  testWidgets('full chat flow', (tester) async {
    await tester.pumpWidget(const VideApp());
    
    // Connect to server
    await tester.tap(find.byType(ServerConfigDialog));
    await tester.enterText(find.byType(TextField), 'http://localhost:8080');
    await tester.tap(find.text('Connect'));
    
    // Create session
    await tester.enterText(find.byKey(Key('message_input')), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    
    // Verify response appears
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('I'), findsWidgets);
  });
}
```

### E2E Tests
- Use `integration_test` package with real vide_server
- Test complete flows: create session → chat → view history

---

## 10. File Structure

```
packages/vide_flutter/
├── lib/
│   ├── main.dart                           # Entry point
│   ├── app.dart                            # MaterialApp setup
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart          # API paths
│   │   │   └── ui_constants.dart           # Spacing, sizes
│   │   ├── errors/
│   │   │   └── app_exception.dart          # Custom exceptions
│   │   ├── extensions/
│   │   │   └── context_extensions.dart     # BuildContext helpers
│   │   ├── router/
│   │   │   └── app_router.dart             # go_router config
│   │   ├── theme/
│   │   │   └── app_theme.dart              # ThemeData
│   │   └── utils/
│   │       ├── debouncer.dart
│   │       └── logger.dart
│   │
│   ├── data/
│   │   ├── api/
│   │   │   ├── vide_api_client.dart        # Main API client
│   │   │   └── websocket_client.dart       # WebSocket stream handler
│   │   ├── models/
│   │   │   ├── session.dart
│   │   │   ├── session.freezed.dart
│   │   │   ├── session.g.dart
│   │   │   ├── create_session_response.dart
│   │   │   ├── agent.dart
│   │   │   ├── chat_message.dart
│   │   │   ├── tool_call.dart
│   │   │   ├── websocket_event.dart
│   │   │   └── directory_entry.dart        # For folder browser
│   │   └── repositories/
│   │       └── session_repository_impl.dart
│   │
│   ├── domain/
│   │   ├── models/                          # Domain-specific models if needed
│   │   ├── repositories/
│   │   │   └── session_repository.dart      # Abstract interface
│   │   └── vide_chat_history_provider.dart  # dartantic_chat provider
│   │
│   ├── presentation/
│   │   ├── pages/
│   │   │   ├── home_page.dart
│   │   │   ├── chat_page.dart
│   │   │   ├── history_page.dart
│   │   │   └── settings_page.dart
│   │   └── widgets/
│   │       ├── chat/
│   │       │   ├── vide_chat_view.dart      # dartantic_chat wrapper
│   │       │   ├── message_input.dart
│   │       │   └── tool_approval_dialog.dart # Tool approval UI
│   │       ├── tool_widgets/
│   │       │   ├── diff_widget.dart
│   │       │   ├── terminal_widget.dart
│   │       │   ├── file_tree_widget.dart
│   │       │   ├── todo_list_widget.dart
│   │       │   └── default_tool_widget.dart
│   │       ├── common/
│   │       │   ├── agent_status_indicator.dart
│   │       │   ├── copy_button.dart
│   │       │   └── loading_skeleton.dart
│   │       └── layout/
│   │           ├── app_scaffold.dart
│   │           ├── sidebar.dart
│   │           └── responsive_layout.dart
│   │
│   └── providers/
│       ├── config_provider.dart
│       ├── config_provider.g.dart
│       ├── api_client_provider.dart
│       ├── session_provider.dart
│       ├── chat_provider.dart
│       ├── websocket_provider.dart         # WebSocket connection management
│       └── agent_status_provider.dart
│
├── test/
│   ├── providers/
│   ├── widgets/
│   └── mocks/
│
├── integration_test/
│   └── app_test.dart
│
├── web/
│   ├── index.html
│   ├── manifest.json
│   └── favicon.png
│
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 11. Dependencies

```yaml
# packages/vide_flutter/pubspec.yaml
name: vide_flutter
description: Flutter GUI for Vide AI coding assistant
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: '>=3.24.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Navigation
  go_router: ^14.6.0

  # AI Chat UI (external dependency from dartantic monorepo)
  dartantic_chat:
    path: /Users/csells/Code/csells/dartantic/packages/dartantic_chat

  # HTTP & Networking
  dio: ^5.7.0
  web_socket_channel: ^3.0.0    # WebSocket for real-time streaming

  # Data Classes
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # UI Components
  flutter_markdown: ^0.7.4
  flutter_highlight: ^0.7.0
  google_fonts: ^6.2.1

  # Utilities
  uuid: ^4.5.1
  intl: ^0.19.0
  shared_preferences: ^2.3.3
  url_launcher: ^6.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

  # Code Generation
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  riverpod_generator: ^2.6.2

  # Testing
  mocktail: ^1.0.4
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/fonts/
```

### dartantic_chat Dependency

The `dartantic_chat` package is an external dependency from the dartantic monorepo. It provides:
- ChatHistoryProvider interface for custom backend integration
- AgentChatView widget for chat UI
- Custom response widgets via responseBuilder
- Multi-agent timeline support

**Development Note:** During development, vide_flutter uses a local path dependency. For production, this should be updated to use a git dependency or published package once dartantic_chat is released.

---

## 12. Development Workflow

### Local Development Setup

```bash
# 1. Navigate to vide_flutter package
cd packages/vide_flutter

# 2. Get dependencies
flutter pub get

# 3. Generate code (freezed, json_serializable, riverpod)
dart run build_runner build --delete-conflicting-outputs

# 4. Start vide_server (in separate terminal)
cd ../vide_server
dart run bin/vide_server.dart

# 5. Run Flutter web app
cd ../vide_flutter
flutter run -d chrome
```

### Running Against Localhost vide_server
1. Start vide_server: `dart run bin/vide_server.dart`
2. Note the printed URL (e.g., `http://127.0.0.1:54321`)
3. In vide_flutter, configure server URL in settings or via environment

### Building for Production

```bash
# Web build
flutter build web --release

# Output in build/web/
# Deploy to static hosting (Vercel, Netlify, Firebase Hosting)
```

### Environment Configuration
```dart
// lib/core/config/env_config.dart
class EnvConfig {
  static String get serverUrl => 
    const String.fromEnvironment('SERVER_URL', defaultValue: 'http://localhost:8080');
}

// Build with custom URL:
// flutter build web --dart-define=SERVER_URL=https://api.vide.app
```

---

## 13. Future Considerations

### Desktop Platform Adaptations
- **Window management**: Multiple windows for different sessions
- **System tray**: Background agent monitoring
- **File system access**: Native file picker for working directory
- **Keyboard shortcuts**: System-level shortcuts

### Mobile Platform Adaptations
- **Push notifications**: Agent completion alerts
- **Background sync**: Fetch updates when app backgrounded
- **Compact UI**: Optimized for smaller screens
- **Gesture navigation**: Swipe to switch sessions

### Offline Support
- **Message queuing**: Queue messages when offline, send when reconnected
- **Local caching**: Cache recent conversations in SQLite
- **Sync protocol**: Reconcile local and server state

### Advanced Features Beyond Phase 4
- **Collaborative editing**: Multiple users on same session (requires auth)
- **Image attachments**: Send screenshots to agent
- **Plugin system**: Custom tool visualization plugins
- **Export/import**: Export conversations to Markdown/JSON

---

## Appendix A: WebSocket Event Types Reference

All events include these common fields:
- `seq` - Session-scoped sequence number for ordering and deduplication
- `event-id` - UUID for this event (shared across partial message chunks)
- `agent-id` - Which agent produced this event
- `agent-type` - Agent type: "main", "implementation", "planning", "context-collection"
- `agent-name` - Human-readable agent name (optional)
- `task-name` - Current task name (optional)
- `timestamp` - ISO 8601 timestamp

### Server → Client Events

| Type | Description | Data Fields |
|------|-------------|-------------|
| `connected` | Initial connection established | `session-id`, `main-agent-id`, `last-seq`, `agents[]`, `metadata` |
| `history` | All session events for state recovery | `events[]`, `last-seq` |
| `status` | Agent status changed | `status`: "working" / "waiting-for-agent" / "waiting-for-user" / "idle" |
| `message` | Streaming text (+ `is-partial` flag) | `role`, `content` |
| `tool-use` | Agent invoking a tool | `tool-use-id`, `tool-name`, `tool-input` |
| `tool-result` | Tool execution result | `tool-use-id`, `tool-name`, `result`, `is-error` |
| `permission-request` | Tool needs user approval | `request-id`, `tool-name`, `tool-input`, `permission-suggestions?` |
| `permission-timeout` | Permission request timed out | `request-id`, `tool-name`, `timeout-seconds` |
| `agent-spawned` | New agent added to session | `spawned-by` |
| `agent-terminated` | Agent removed from session | `terminated-by`, `reason` |
| `aborted` | Operation cancelled | `reason` |
| `done` | Agent turn complete | `reason` |
| `error` | Error occurred | `message`, `code`, `original-message?` |

### Streaming Behavior

1. Server sends `message` events with `is-partial: true` for streaming chunks
2. All chunks for the same logical message share the same `event-id`
3. Client accumulates chunks with matching `event-id`
4. Final chunk has `is-partial: false` (content may be empty)
5. `seq` enables ordering and deduplication on reconnect
6. Tool events (`tool-use`, `tool-result`) are sent when detected
7. `permission-request` events pause agent execution until client responds or timeout
8. `done` signals the agent has finished its turn

**Example streaming sequence:**
```json
{"seq": 3, "event-id": "550e8400-...", "type": "message", "is-partial": true, "data": {"role": "assistant", "content": "Let me "}, ...}
{"seq": 4, "event-id": "550e8400-...", "type": "message", "is-partial": true, "data": {"role": "assistant", "content": "help you "}, ...}
{"seq": 5, "event-id": "550e8400-...", "type": "message", "is-partial": true, "data": {"role": "assistant", "content": "with that."}, ...}
{"seq": 6, "event-id": "550e8400-...", "type": "message", "is-partial": false, "data": {"role": "assistant", "content": ""}, ...}
```

### Client → Server Messages

The client can send JSON messages through the WebSocket connection:

| Type | Description | Fields |
|------|-------------|--------|
| `user-message` | Send message to conversation | `content`, `model?`, `permission-mode?` |
| `permission-response` | Respond to permission request | `request-id`, `allow`, `message?` |
| `abort` | Cancel all active agent operations | (none) |

**user-message Example:**
```json
{
  "type": "user-message",
  "content": "Now make it print goodbye too",
  "model": "opus",
  "permission-mode": "ask"
}
```

**permission-response Examples:**
```json
// Allow the tool
{"type": "permission-response", "request-id": "abc-123", "allow": true}

// Deny the tool
{"type": "permission-response", "request-id": "abc-123", "allow": false, "message": "User declined"}
```

**abort Example:**
```json
{"type": "abort"}
```
When client sends `abort`, server cancels ALL active agents and sends an `aborted` event for each.

## Appendix B: REST API Quick Reference

All JSON uses kebab-case for property names.

### Implemented Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /health` | GET | Health check (returns `{"status": "ok", "version": "0.1.0"}`) |
| `POST /api/v1/sessions` | POST | Create new session |
| `ws://.../api/v1/sessions/{session-id}/stream` | WS | Bidirectional WebSocket (all agents multiplexed) |
| `GET /api/v1/filesystem` | GET | List directory contents |
| `POST /api/v1/filesystem` | POST | Create new folder |

### POST /api/v1/sessions - Create Session

**Request:**
```json
{
  "initial-message": "Write a hello world program",
  "working-directory": "/Users/chris/myproject",
  "model": "opus",              // optional: "sonnet" (default), "opus", "haiku"
  "permission-mode": "ask"      // optional: "accept-edits" (default), "plan", "ask", "deny"
}
```

**Response:**
```json
{
  "session-id": "550e8400-e29b-41d4-a716-446655440000",
  "main-agent-id": "660e8400-e29b-41d4-a716-446655440001",
  "created-at": "2025-12-21T10:00:00Z"
}
```

### Bidirectional WebSocket

**Endpoint:** `ws://{host}:{port}/api/v1/sessions/{session-id}/stream`

**Features:**
- Single connection per session, receives events from ALL agents (main + spawned)
- Each event includes: `seq`, `event-id`, `agent-id`, `agent-type`, `agent-name`, `task-name`, `timestamp`
- Unified timeline approach - no per-agent connections needed
- Client sends messages via WebSocket (not HTTP POST):
  - `user-message` - Send message to conversation
  - `permission-response` - Allow/deny tool approval request
  - `abort` - Cancel all active agent operations
- See Appendix A for complete event and message type reference

### Filesystem Endpoints

**GET /api/v1/filesystem** - List directory contents
- Query param: `parent` (optional) - path to list children of; null/omitted = server root
- Response: `{ "entries": [{ "name": "...", "path": "...", "is-directory": true }] }`
- Returns both files and folders; client filters as needed
- Symlinks are NOT followed (security measure)

**POST /api/v1/filesystem** - Create folder
- Body: `{ "parent": "/path/to/parent", "name": "new-folder" }`
- Response: `{ "path": "/path/to/parent/new-folder" }`
- Server enforces root directory restriction

### Error Response Format

All errors return consistent JSON:
```json
{
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

Common error codes: `INVALID_REQUEST`, `INVALID_WORKING_DIRECTORY`, `NOT_FOUND`, `INTERNAL_ERROR`

### Future Endpoints (Not Yet Implemented)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /api/v1/sessions` | GET | List sessions |
| `GET /api/v1/sessions/:id` | GET | Get session details |
| `DELETE /api/v1/sessions/:id` | DELETE | Delete session |
| `GET /api/v1/sessions/:id/memory` | GET | Get agent memories |
