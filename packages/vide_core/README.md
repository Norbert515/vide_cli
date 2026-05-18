# vide_core

Core business logic for Vide CLI - a multi-agent orchestration system built on Claude SDK.

This package is shared between the TUI (Terminal UI) and REST API implementations, providing a clean separation between UI and business logic.

## Installation

This package is part of the Vide CLI monorepo and not published to pub.dev.

```yaml
dependencies:
  vide_core:
    path: ../vide_core
```

## Quick Start

```dart
import 'package:riverpod/riverpod.dart';
import 'package:vide_core/vide_core.dart';

void main() async {
  // Create session manager with isolated containers (each session independent)
  final permissionHandler = PermissionHandler();
  final container = ProviderContainer(
    overrides: [
      videConfigManagerProvider.overrideWithValue(VideConfigManager()),
      workingDirProvider.overrideWithValue(Directory.current.path),
    ],
  );
  final sessionManager = LocalVideSessionManager.isolated(
    container,
    permissionHandler,
  );

  // Start a new session
  final session = await sessionManager.createSession(
    workingDirectory: '/path/to/project',
    initialMessage: 'Help me fix the bug in auth.dart',
  );

  // Listen to events from all agents
  session.events.listen((event) {
    switch (event) {
      case MessageEvent e:
        stdout.write(e.content);
      case ToolUseEvent e:
        print('[Tool: ${e.toolName}]');
      case ToolResultEvent e:
        if (e.isError) print('[Error: ${e.result}]');
      case TurnCompleteEvent e:
        print('\n--- Turn complete ---');
      case AgentSpawnedEvent e:
        print('[Agent spawned: ${e.agentName}]');
      case AgentTerminatedEvent e:
        print('[Agent terminated: ${e.agentId}]');
      case PermissionRequestEvent e:
        // Handle permission request
        session.respondToPermission(e.requestId, allow: true);
      case StatusEvent e:
        // Agent status changed (working, idle, waitingForAgent, waitingForUser)
      case ErrorEvent e:
        print('[Error: ${e.message}]');
    }
  });

  // Send follow-up messages
  session.sendMessage('Can you also add tests?');

  // Clean up when done
  await session.dispose();
  sessionManager.dispose();
  container.dispose();
}
```

## Architecture

### Multi-Agent System

Vide orchestrates a network of specialized agents that communicate asynchronously:

| Agent Type | Purpose | MCP Servers |
|------------|---------|-------------|
| **Main** | Triage, delegation, coordination | Git, Agent, TaskManagement, AskUserQuestion |
| **Implementation** | Code writing, bug fixes | Git, TaskManagement, FlutterRuntime |
| **Context Collection** | Codebase exploration, research | TaskManagement |
| **Flutter Tester** | UI testing, screenshots | FlutterRuntime, TaskManagement |
| **Planning** | Implementation planning | TaskManagement |

Agents spawn sub-agents using the `spawnAgent` MCP tool and communicate via `sendMessageToAgent`. The system is fully asynchronous - spawned agents work independently and message back when complete.

### Package Structure

```
lib/
├── api/                      # Public API (recommended entry point)
├── agents/                   # Agent configurations
├── mcp/                      # MCP server implementations
│   ├── agent/                # Agent network operations
│   ├── ask_user_question/    # User dialog MCP
│   ├── git/                  # Git operations
│   └── task_management/      # Task naming
├── models/                   # Core data structures
├── services/                 # Business logic
│   ├── permissions/          # Permission checking
│   └── settings/             # Settings management
├── state/                    # Riverpod state management
└── utils/                    # Shared utilities
```

## API Overview

### Public API (`api.dart`)

The recommended entry point for new consumers. Provides a clean interface without exposing internal details.

**Core Classes:**

- `LocalVideSessionManager` - Main entry point for creating sessions
- `VideSession` - Active session with agent network
- `VideEvent` - Sealed event hierarchy
- `VideAgent` - Immutable agent state snapshot
- `RemoteVideSession` - Client for connecting to remote daemon sessions

**Event Types:**

| Event | Description |
|-------|-------------|
| `MessageEvent` | Streaming text content from agents |
| `ToolUseEvent` | Agent invoking a tool |
| `ToolResultEvent` | Tool execution result |
| `StatusEvent` | Agent status change |
| `TurnCompleteEvent` | Turn completed with token stats |
| `AgentSpawnedEvent` | New agent joined network |
| `AgentTerminatedEvent` | Agent removed from network |
| `PermissionRequestEvent` | Permission needed for tool |
| `ErrorEvent` | Error occurred |

### Internal API (`vide_core.dart`)

Exports all internal components for advanced use cases (TUI uses this). Includes direct access to:

- Riverpod providers
- Agent configurations
- MCP servers
- Permission system
- Settings management

## Key Components

### Services

**AgentNetworkManager** - Core agent lifecycle orchestration
```dart
final manager = container.read(agentNetworkManagerProvider.notifier);
await manager.spawnAgent(role: 'implementer', ...);
```

**ClaudeManager** - Manages ClaudeClient instances per agent
```dart
final client = container.read(claudeProvider(agentId));
```

**VideConfigManager** - Configuration directory management
```dart
final config = VideConfigManager(configRoot: '~/.vide');
final projectDir = config.projectConfigDir('/path/to/project');
```

**PermissionChecker** - Pure permission business logic
```dart
final checker = PermissionChecker(PermissionCheckerConfig(...));
final result = checker.checkPermission(toolPermissionContext);
```

### MCP Servers

**Agent MCP Server** - Agent spawning and messaging
- `spawnAgent` - Create specialized sub-agents (supports optional `workingDirectory` for per-agent worktrees)
- `sendMessageToAgent` - Async message passing
- `setAgentStatus` - Update agent status
- `terminateAgent` - Remove agent

**Git MCP Server** - Comprehensive git operations
- Status, commit, add, diff, log
- Branch, checkout, stash
- Worktree management (list, add, remove, lock, unlock)
- Fetch, pull, merge, rebase

**Task Management MCP** - UI task naming
- `setTaskName` - Overall network goal
- `setAgentTaskName` - Individual agent task

**Ask User Question MCP** - Structured dialogs
- Multiple-choice questions
- Multi-select support
- Headers and descriptions

### Models

```dart
// Agent network state
final network = AgentNetwork(
  id: 'network-123',
  agents: {...},
  workingDirectory: '/path/to/project',
);

// Agent metadata with token tracking
final metadata = AgentMetadata(
  name: 'Bug Fix',
  type: 'implementer',
  totalInputTokens: 1500,
  totalOutputTokens: 500,
  costUsd: 0.003,
);

// Agent status
enum AgentStatus { working, waitingForAgent, waitingForUser, idle }
```

## Provider Override Pattern

vide_core uses Riverpod providers that throw `UnimplementedError` by default. Each UI must override:

```dart
final container = ProviderContainer(overrides: [
  videConfigManagerProvider.overrideWithValue(
    VideConfigManager(configRoot: '~/.vide'),
  ),
  workingDirProvider.overrideWithValue(Directory.current.path),
]);
```

## Session Persistence

Sessions can be persisted and resumed:

```dart
// List available sessions
final sessions = await sessionManager.listSessions();

// Resume a session
final session = await sessionManager.resumeSession(sessionId);

// Delete a session
await sessionManager.deleteSession(sessionId);
```

## User-Defined Agents

Custom agents are loaded from `.claude/agents/*.md` files:

```dart
final loader = AgentLoader(workingDirectory: '/path/to/project');
final customAgents = await loader.loadAgents();
```

## Testing

```bash
dart test
```

Test coverage includes:
- Models (AgentNetwork, AgentMetadata, AgentStatus)
- Services (persistence, permissions, config)
- MCP servers (git client)
- Integration tests (agent lifecycle, permissions)

## Dependencies

| Package | Purpose |
|---------|---------|
| `claude_sdk` | Claude API integration |
| `flutter_runtime_mcp` | Flutter app lifecycle management |
| `riverpod` | State management |
| `freezed_annotation` | Immutable data classes |
| `json_annotation` | JSON serialization |

## Code Generation

After modifying models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Related Packages

- `vide_server` - REST API server using vide_core
- `flutter_runtime_mcp` - Flutter runtime MCP server
- `claude_sdk` - Claude SDK client
