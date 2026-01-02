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
│  │  networkProvider, agentProvider, chatProvider, etc.     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐│
│  │   Models    │ │ Repositories│ │ ChatHistoryProvider     ││
│  │  (Network,  │ │ (Interfaces)│ │  (Custom) for           ││
│  │   Agent)    │ │             │ │                         ││
│  └─────────────┘ └─────────────┘ └─────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  VideApiClient (dio + WebSocket)        ││
│  │  - REST endpoints (POST /networks, POST /messages)      ││
│  │  - WebSocket streaming (ws://.../stream)                ││
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
- **AsyncNotifierProvider** for async state (network creation, message sending)
- **StreamProvider** for WebSocket event streams
- **StateProvider** for simple UI state (selected network, theme)
- **Provider** for computed/derived state

### Navigation (go_router)
- Declarative routing with typed routes
- Deep linking support for web
- Shell route for persistent sidebar/navigation

---

## 2.5 Prerequisites (vide_server)

Before starting vide_flutter development, the following vide_server features must be implemented and tested:

### Multiplexed WebSocket Streaming
- Single WebSocket endpoint per network: `ws://.../api/v1/networks/:id/stream`
- All agent events (main + spawned agents) multiplexed on this single stream
- Each event includes attribution fields: `agentId`, `agentType`, `agentName`, `taskName`
- Client receives unified timeline without managing multiple WebSocket connections

### Bidirectional WebSocket for Permission Requests
- WebSocket is bidirectional: server sends events, client can send responses
- Permission requests sent as `permission_request` event type:
  ```json
  {
    "type": "permission_request",
    "agentId": "...",
    "data": {
      "requestId": "uuid",
      "toolName": "Bash",
      "toolInput": {"command": "rm -rf node_modules"},
      "permissionSuggestions": ["Bash(rm *)"]
    }
  }
  ```
- Client responds by sending a message through the same WebSocket:
  ```json
  {
    "type": "permission_response",
    "requestId": "uuid",
    "allow": true,
    "updatedInput": { ... }
  }
  ```
- Mimics the `CanUseToolCallback` pattern from claude_sdk:
  - Receives: `toolName`, `toolInput`, `context` (with `permissionSuggestions`, `blockedPath`)
  - Returns: allow (with optional `updatedInput`) or deny (with `message`)
- Server blocks agent execution until client responds or times out

### Model Selection Support
- `POST /api/v1/networks/:id/messages` accepts optional `model` field
- Valid values: `"sonnet"` or `"opus"` (default: `"sonnet"`)
- Model selection applies per-message, allowing users to switch mid-conversation

### Filesystem Browsing API
- `GET /api/v1/filesystem?parent=...` endpoint for hierarchical directory listing
  - `parent` parameter: path to list children of; `null`/omitted = server-configured root
  - Returns entries: `{ name, path, isDirectory }` for both files and folders
- `POST /api/v1/filesystem` endpoint for creating new folders
  - Body: `{ parent: string, name: string }`
  - Creates folder at `parent/name`; `parent` must be within server root
  - Returns: `{ path: string }` of created folder
- Server enforces a configurable root directory (prevents access outside allowed scope)
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
- [ ] Create new network with initial message
- [ ] Send messages to network
- [ ] Stream WebSocket responses and display in chat
- [ ] Basic markdown rendering in responses
- [ ] Server URL configuration (localhost default)
- [ ] Working directory browser (server filesystem API)

#### Screens/Pages
1. **HomePage** - Server connection + network list
2. **ChatPage** - Main chat interface with dartantic_chat

#### Widgets/Components
- `ServerConfigDialog` - Configure server URL
- `FolderBrowserDialog` - Browse and select working directory from server filesystem
- `NetworkListTile` - Display network in list
- `ChatView` - dartantic_chat AgentChatView wrapper
- `MessageBubble` - Basic message display

#### API Integration
- `POST /api/v1/networks` - Create network
- `POST /api/v1/networks/:id/messages` - Send message
- `ws://.../api/v1/networks/:id/stream` - WebSocket stream (multiplexed, all agents)
- `GET /api/v1/filesystem?parent=...` - List directory contents (prerequisite)

#### Success Criteria
- Can connect to localhost vide_server
- Can create network and see response
- Can send follow-up messages
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
- Parse WebSocket events by type: `connected`, `status`, `message`, `message_delta`, `tool_use`, `tool_result`, `done`, `error`
- Handle multiplexed agent events (different agentId in stream)
- Correlate tool calls with results via `toolUseId`

#### Success Criteria
- Tool calls render with appropriate visualization
- Can see which agent is active
- Code diffs are syntax highlighted
- Terminal output looks authentic

---

### Phase 3: Advanced Features (~2-3 days)

#### Features
- [ ] Network history and persistence (local storage)
- [ ] Resume previous networks
- [ ] Permission mode UI (surfaces tool approval requests from WebSocket stream)
- [ ] Model selection dropdown (Sonnet, Opus - set per-message)
- [ ] Memory viewer (read-only)
- [ ] Settings page (theme, server URL, preferences)
- [ ] Responsive design (mobile-friendly)

#### Screens/Pages
1. **HistoryPage** - List of past networks
2. **SettingsPage** - App configuration
3. **MemoryViewerPage** - View agent memories

#### Widgets/Components
- `ToolApprovalDialog` - Displays pending tool calls requiring user approval
- `ModelDropdown` - Model selection (Sonnet/Opus, persisted per-session, applied per-message)
- `MemoryEntryCard` - Display memory entry
- `NetworkHistoryList` - Searchable history
- `ThemeToggle` - Light/dark mode

#### API Integration
- `GET /api/v1/networks` - List networks (future server endpoint)
- `GET /api/v1/networks/:id` - Get network details
- `GET /api/v1/networks/:id/memory` - Get memories (future)

#### Success Criteria
- Can browse network history
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

The `ChatMessage.text` field contains a JSON structure that accumulates WebSocket events as they stream in. The `responseBuilder` parses this JSON to render rich Flutter widgets.

**Event accumulation flow:**
1. WebSocket receives `text_event` → Append to `events` array in JSON
2. WebSocket receives `tool_call_event` → Append tool call to `events` array
3. WebSocket receives `tool_result_event` → Append tool result to `events` array
4. `responseBuilder` parses the JSON and renders appropriate widgets

**ChatMessage.text JSON structure:**
```json
{
  "events": [
    {"type": "text", "content": "Let me help you with that."},
    {"type": "tool_call", "callId": "123", "name": "Bash", "args": {"command": "ls -la"}},
    {"type": "tool_result", "callId": "123", "result": "file1.txt\nfile2.txt", "isError": false},
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
    'tool_call' => ToolCallWidget(
      callId: event['callId'] as String,
      name: event['name'] as String,
      args: event['args'] as Map<String, dynamic>,
    ),
    'tool_result' => ToolResultWidget(
      callId: event['callId'] as String,
      result: event['result'] as String,
      isError: event['isError'] as bool? ?? false,
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
  final VideApiClient _apiClient;
  final String _networkId;
  final String _mainAgentId;
  final WebSocketClient _wsClient;

  // Internal message history (provider manages this)
  final List<ChatMessage> _history = [];

  // Accumulated text for current response (built from deltas)
  String _currentResponseText = '';

  // Current agent context (for multi-agent timeline attribution)
  String? _currentAgentId;
  String? _currentAgentType;
  String? _currentAgentName;

  VideChatHistoryProvider({
    required VideApiClient apiClient,
    required String networkId,
    required String mainAgentId,
    required WebSocketClient wsClient,
  }) : _apiClient = apiClient,
       _networkId = networkId,
       _mainAgentId = mainAgentId,
       _wsClient = wsClient;

  @override
  Stream<String> sendMessageStream(String message) async* {
    // 1. Add user message to history
    _history.add(ChatMessage.user(message));
    _currentResponseText = '';

    // 2. Send to vide_server (returns immediately)
    await _apiClient.sendMessage(_networkId, message);

    // 3. Listen to WebSocket stream for events
    await for (final event in _wsClient.events) {
      // Track current agent for multi-agent timeline attribution
      _currentAgentId = event.agentId;
      _currentAgentType = event.agentType;
      _currentAgentName = event.agentName;

      switch (event.type) {
        case 'message':
          // Full message (first chunk or non-streaming)
          final content = event.data['content'] as String?;
          if (content != null) {
            _currentResponseText = content;
            yield _currentResponseText;
          }
        case 'message_delta':
          // Streaming delta - append to current response
          final delta = event.data['delta'] as String?;
          if (delta != null) {
            _currentResponseText += delta;
            yield _currentResponseText;
          }
        case 'done':
          // Turn complete - finalize history with agent attribution
          _history.add(ChatMessage(
            role: ChatMessageRole.model,
            parts: [TextPart(_currentResponseText)],
            metadata: {
              'agentId': _currentAgentId,
              'agentType': _currentAgentType,
              'agentName': _currentAgentName,
            },
          ));
          return;
        case 'error':
          throw Exception(event.data['message'] as String? ?? 'Unknown error');
        // tool_use and tool_result handled via responseBuilder
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

### WebSocket Event Streaming

```dart
// lib/data/api/websocket_client.dart

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();

  Stream<WebSocketEvent> get events => _eventController.stream;

  /// Connect to the WebSocket stream for a network/agent
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
    final agentId = message.metadata?['agentId'] as String?;
    final agentType = message.metadata?['agentType'] as String?;
    final agentName = message.metadata?['agentName'] as String?;

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

The provider needs to handle the multiplexed WebSocket event structure:

```dart
// lib/data/models/websocket_event.dart

@freezed
class WebSocketEvent with _$WebSocketEvent {
  const factory WebSocketEvent({
    required String agentId,
    required String agentType,      // "main", "implementation", "planning", "contextCollection"
    String? agentName,
    String? taskName,
    required String type,           // Event types listed below
    required dynamic data,
    required DateTime timestamp,
  }) = _WebSocketEvent;

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) =>
      _$WebSocketEventFromJson(json);
}

/// Event Types:
/// - `connected` - Initial WebSocket connection established (not a status value)
/// - `status` - Agent status changed (data: {status: "idle" | "working" | "waitingForAgent" | "waitingForUser"})
/// - `message` - New full message (data: {role: string, content: string})
/// - `message_delta` - Streaming text chunk (data: {role: string, delta: string})
/// - `tool_use` - Agent invoking a tool (data: {toolName: string, toolInput: object, toolUseId: string})
/// - `tool_result` - Tool execution result (data: {toolName: string, result: string, isError: bool, toolUseId: string})
/// - `done` - Agent turn complete
/// - `error` - Error occurred (data: {message: string, stack?: string})
```

### Multi-Agent Timeline Support

The unified timeline displays messages from all agents (main, implementation, planning, etc.) in chronological order with visual attribution. This is achieved by:

1. **Agent metadata in ChatMessage**: Each message stores `agentId`, `agentType`, and `agentName` in `ChatMessage.metadata`
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
    'contextCollection' => Colors.orange,
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
│ │   Network    │ │              Chat Area                     │ │
│ │   History    │ │                                            │ │
│ │              │ │  ┌──────────────────────────────────────┐  │ │
│ │  • Network 1 │ │  │ Agent: Thinking...              🟢   │  │ │
│ │  • Network 2 │ │  └──────────────────────────────────────┘  │ │
│ │  • Network 3 │ │                                            │ │
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
- **Web**: Persistent sidebar with network list
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

  /// Create a new network
  Future<CreateNetworkResponse> createNetwork({
    required String initialMessage,
    required String workingDirectory,
  }) async {
    final response = await _dio.post('/api/v1/networks', data: {
      'initialMessage': initialMessage,
      'workingDirectory': workingDirectory,
    });
    return CreateNetworkResponse.fromJson(response.data);
  }

  /// Send message to network
  /// [model] - optional model override: "sonnet" or "opus" (default: sonnet)
  Future<void> sendMessage(
    String networkId,
    String content, {
    String? model,
  }) async {
    await _dio.post('/api/v1/networks/$networkId/messages', data: {
      'content': content,
      if (model != null) 'model': model,
    });
  }

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

  /// Get WebSocket URL for streaming events (multiplexed stream for all agents)
  String getWebSocketUrl(String networkId) {
    final wsBase = _baseUrl.replaceFirst('http', 'ws');
    return '$wsBase/api/v1/networks/$networkId/stream';
  }
}
```

### Models

```dart
// lib/data/models/network.dart
@freezed
class Network with _$Network {
  const factory Network({
    required String id,
    required String goal,
    required List<Agent> agents,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    String? workingDirectory,
    String? worktreePath,         // Git worktree path if using worktrees
  }) = _Network;
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
// - Metadata map for agent attribution (agentId, agentType, agentName)

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
    required bool isDirectory,
  }) = _DirectoryEntry;

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) =>
      _$DirectoryEntryFromJson(json);
}
```

### Caching Strategy
- **Network list**: Cache in Riverpod provider, refresh on demand
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

// lib/providers/network_provider.dart
@riverpod
class CurrentNetwork extends _$CurrentNetwork {
  @override
  AsyncValue<Network?> build() => const AsyncValue.data(null);

  Future<void> createNetwork(String initialMessage, String workingDir) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.createNetwork(
        initialMessage: initialMessage,
        workingDirectory: workingDir,
      );
      state = AsyncValue.data(Network(
        id: response.networkId,
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
  Stream<WebSocketEvent> build(String networkId) async* {
    final api = ref.watch(apiClientProvider);
    final wsUrl = api.getWebSocketUrl(networkId);

    _client = WebSocketClient();
    await _client!.connect(wsUrl);

    ref.onDispose(() => _client?.disconnect());

    // All agent events are multiplexed on this single stream
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
// lib/domain/repositories/network_repository.dart
abstract class NetworkRepository {
  Future<Network> createNetwork(String message, String workingDir);
  Future<void> sendMessage(String networkId, String content);
  Stream<WebSocketEvent> streamEvents(String networkId);  // Multiplexed stream
}

// lib/data/repositories/network_repository_impl.dart
class NetworkRepositoryImpl implements NetworkRepository {
  final VideApiClient _apiClient;
  
  NetworkRepositoryImpl(this._apiClient);
  
  @override
  Future<Network> createNetwork(String message, String workingDir) async {
    final response = await _apiClient.createNetwork(
      initialMessage: message,
      workingDirectory: workingDir,
    );
    return Network(id: response.networkId, ...);
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
class CurrentNetwork extends _$CurrentNetwork {
  Future<void> createNetwork(...) async {
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
// test/providers/network_provider_test.dart
void main() {
  group('CurrentNetwork', () {
    test('createNetwork updates state on success', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(MockVideApiClient()),
      ]);
      
      await container.read(currentNetworkProvider.notifier)
        .createNetwork('Test message', '/path');
      
      expect(
        container.read(currentNetworkProvider),
        isA<AsyncData<Network>>(),
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
    
    // Create network
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
- Test complete flows: create network → chat → view history

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
│   │   │   ├── network.dart
│   │   │   ├── network.freezed.dart
│   │   │   ├── network.g.dart
│   │   │   ├── agent.dart
│   │   │   ├── chat_message.dart
│   │   │   ├── tool_call.dart
│   │   │   ├── websocket_event.dart
│   │   │   └── directory_entry.dart        # For folder browser
│   │   └── repositories/
│   │       └── network_repository_impl.dart
│   │
│   ├── domain/
│   │   ├── models/                          # Domain-specific models if needed
│   │   ├── repositories/
│   │   │   └── network_repository.dart      # Abstract interface
│   │   └── vide_llm_provider.dart           # dartantic_chat provider
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
│       ├── network_provider.dart
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
- **Window management**: Multiple windows for different networks
- **System tray**: Background agent monitoring
- **File system access**: Native file picker for working directory
- **Keyboard shortcuts**: System-level shortcuts

### Mobile Platform Adaptations
- **Push notifications**: Agent completion alerts
- **Background sync**: Fetch updates when app backgrounded
- **Compact UI**: Optimized for smaller screens
- **Gesture navigation**: Swipe to switch networks

### Offline Support
- **Message queuing**: Queue messages when offline, send when reconnected
- **Local caching**: Cache recent conversations in SQLite
- **Sync protocol**: Reconcile local and server state

### Advanced Features Beyond Phase 4
- **Collaborative editing**: Multiple users on same network (requires auth)
- **Image attachments**: Send screenshots to agent
- **Plugin system**: Custom tool visualization plugins
- **Export/import**: Export conversations to Markdown/JSON

---

## Appendix A: WebSocket Event Types Reference

| Type | Description | Data Fields |
|------|-------------|-------------|
| `connected` | Initial WebSocket connection | `networkId: string, agentId: string` |
| `status` | Agent status changed | `status: string` (idle/working/waitingForAgent/waitingForUser) |
| `message` | New full message (first chunk) | `role: string, content: string` |
| `message_delta` | Streaming text chunk | `role: string, delta: string` |
| `tool_use` | Agent invoking a tool | `toolName: string, toolInput: object, toolUseId: string` |
| `tool_result` | Result from tool execution | `toolName: string, result: string, isError: bool, toolUseId: string` |
| `permission_request` | Tool needs user approval | `requestId: string, toolName: string, toolInput: object, permissionSuggestions?: string[]` |
| `done` | Agent turn complete | (no data) |
| `error` | Error occurred | `message: string, stack?: string` |

### Streaming Behavior

1. When Claude generates text, the first event is `message` with initial content
2. Subsequent events are `message_delta` containing only the new characters
3. Client should append deltas to build the complete response
4. Tool events (`tool_use`, `tool_result`) are sent when detected
5. `permission_request` events pause agent execution until client responds
6. `done` signals the agent has finished its turn

### Client-to-Server Messages (Bidirectional WebSocket)

The client can send JSON messages through the WebSocket connection:

| Type | Description | Fields |
|------|-------------|--------|
| `permission_response` | Respond to permission request | `requestId: string, allow: bool, updatedInput?: object, message?: string` |

**Permission Response Examples:**
```json
// Allow the tool
{"type": "permission_response", "requestId": "abc-123", "allow": true}

// Allow with modified input
{"type": "permission_response", "requestId": "abc-123", "allow": true, "updatedInput": {"command": "ls"}}

// Deny the tool
{"type": "permission_response", "requestId": "abc-123", "allow": false, "message": "User declined"}
```

## Appendix B: REST API Quick Reference

### Implemented Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/networks` | POST | Create new network |
| `/api/v1/networks/:id/messages` | POST | Send message (body: `{content, model?}` where model is "sonnet" or "opus") |

### Prerequisite Endpoints (must be implemented before vide_flutter)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/networks/:id/stream` | WS | Multiplexed bidirectional WebSocket stream (all agents) |
| `/api/v1/filesystem` | GET | List directory contents |
| `/api/v1/filesystem` | POST | Create new folder |

**Multiplexed Bidirectional WebSocket Details:**
- Single connection per network, receives events from all agents
- Each event includes: `agentId`, `agentType`, `agentName`, `taskName` for attribution
- Replaces per-agent streams with unified timeline approach
- Client can send messages (e.g., `permission_response`) through the same connection
- See "Client-to-Server Messages" in Appendix A for message types

**Filesystem GET Endpoint:**
- Query param: `parent` (optional) - path to list children of; null/omitted = server root
- Response: `{ entries: [{ name: string, path: string, isDirectory: bool }] }`
- Returns both files and folders; client filters as needed

**Filesystem POST Endpoint:**
- Body: `{ parent: string, name: string }`
- Creates folder at `parent/name`
- Response: `{ path: string }` of created folder
- Server configures root directory to restrict all operations within allowed scope

### Future Endpoints (Not Yet Implemented)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/networks` | GET | List networks |
| `/api/v1/networks/:id` | GET | Get network details |
| `/api/v1/networks/:id/memory` | GET | Get agent memories |
