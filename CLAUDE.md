# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vide CLI is an agentic system for Claude Code, built specifically for Flutter developers. It implements a multi-agent architecture where specialized agents collaborate asynchronously via message passing to accomplish development tasks.

**Current Status:** The project supports dual-interface architecture:
- **TUI (Terminal UI)**: Fully functional interactive CLI
- **REST API**: HTTP server exposing agent network functionality via WebSocket streaming

Both interfaces share the same core business logic via the `vide_core` package.

## Package Structure

The codebase is organized into multiple packages:

```
vide_cli/ (repo root)
├── lib/                        # TUI-specific code
│   ├── modules/                # TUI pages, components, scopes
│   │   ├── agent_network/      # UI for agent networks
│   │   ├── permissions/        # Permission dialogs and TUI adapter
│   │   └── settings/           # Settings UI
│   ├── components/             # Reusable TUI components
│   └── services/               # TUI-specific services (Sentry)
├── packages/
│   ├── vide_core/             # ⭐ Shared business logic
│   │   ├── models/            # Core data models (AgentNetwork, Permission)
│   │   ├── services/          # Business logic (AgentNetworkManager, ClaudeManager)
│   │   ├── mcp/               # MCP servers (agent, git, memory, task)
│   │   ├── agents/            # Agent configurations and loader
│   │   ├── state/             # Riverpod state managers
│   │   └── utils/             # Shared utilities
│   ├── vide_server/           # REST API server with WebSocket streaming
│   ├── flutter_runtime_mcp/   # Flutter app lifecycle management
│   ├── runtime_ai_dev_tools/  # Flutter service extensions
│   ├── claude_sdk/            # Claude SDK client
│   └── moondream_api/         # Vision AI client
```

### Provider Override Pattern

`vide_core` uses Riverpod providers that throw `UnimplementedError` by default. Each UI (TUI, REST) must override these providers with concrete implementations:

```dart
final container = ProviderContainer(overrides: [
  videConfigManagerProvider.overrideWithValue(
    VideConfigManager(configRoot: '~/.vide'),  // TUI uses ~/.vide
  ),
  workingDirProvider.overrideWithValue(Directory.current.path),
  // permissionProvider - not currently used by TUI (hook-based system)
]);
```

**Key Providers in vide_core:**
- `videConfigManagerProvider` - Config directory management
- `workingDirProvider` - Working directory for operations
- `permissionProvider` - Permission request abstraction (future use)

## Issue Tracking

This project uses **bd** (beads) for issue tracking:

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status=in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

Run `bd onboard` when starting work on this project.

## Development Commands

### Building and Running

```bash
# Get dependencies
dart pub get

# Compile executable locally (for testing)
dart compile exe bin/vide.dart -o vide

# Run from source (development mode)
dart run bin/vide.dart
```

### Additional Build Commands

The project uses `just` for common tasks:

```bash
just compile          # Compile native binary
just install          # Install to ~/.local/bin
just generate-devtools # Regenerate bundled devtools
```

### Testing

```bash
# Run all tests (root project)
dart test

# Run specific test file
dart test test/permission_matcher_test.dart

# Run vide_server tests (includes end-to-end integration tests)
cd packages/vide_server && dart test
```

### Code Generation

```bash
# Generate bundled devtools code (after changing runtime_ai_dev_tools)
just generate-devtools
```

### Analysis

```bash
# Run Dart analyzer
dart analyze
```

## Architecture

### Multi-Agent System

Vide orchestrates a network of specialized agents that communicate asynchronously:

- **Main Agent (Orchestrator)**: Never writes code. Assesses tasks, clarifies requirements, delegates to specialized agents
- **Implementation Agent**: Writes and edits code, fixes bugs, implements features
- **Context Collection Agent**: Explores codebase, researches patterns, gathers context
- **Flutter Tester Agent**: Runs Flutter apps, takes screenshots, validates changes via UI interaction
- **Planning Agent**: Creates detailed implementation plans for complex tasks

Agents spawn each other using `spawnAgent` MCP tool and communicate via `sendMessageToAgent`. The system is fully asynchronous - spawned agents work independently and message back when complete.

### Key Modules

**vide_core Package** (`packages/vide_core/`)
- `services/agent_network_manager.dart` - Core agent lifecycle management (spawn, message, terminate)
- `services/claude_manager.dart` - Manages ClaudeClient instances per agent
- `models/agent_network.dart` - Agent network data structures
- `state/agent_status_manager.dart` - Tracks agent status (working, waiting, idle)
- `services/memory_service.dart` - Stores build commands, platform choices across sessions
- `models/permission.dart` - Permission request/response data models
- `services/permission_provider.dart` - Permission abstraction interface

**Agent Configurations** (`packages/vide_core/lib/agents/`)
- Agent prompt configurations for each agent type (main, implementation, context collection, planning, flutter tester)
- `prompt_sections/` - Reusable prompt sections (Flutter, Dart, Git workflows, tool usage, etc.)
- `agent_loader.dart` - Loads user-defined agents from `.claude/agents/*.md`

**MCP Servers** (`packages/vide_core/lib/mcp/`)
- `agent/agent/agent_mcp_server.dart` - Agent spawning, messaging, status management
- `git/git/git_server.dart` - Git operations including worktree support
- `git/git/git_client.dart` - Git client wrapper
- `task_management/task_management/task_management_server.dart` - Task naming for UI display
- `memory_mcp_server.dart` - Persistent key-value storage scoped to project path

**TUI-Specific Modules** (`lib/modules/`)
- `permissions/permission_service.dart` - HTTP server for hook-based permission requests
- `permissions/permission_scope.dart` - UI scope for permission dialogs
- `permissions/permission_service_adapter.dart` - Adapter implementing PermissionProvider (currently unused)
- `settings/local_settings_manager.dart` - Manages `.claude/settings.local.json`
- `settings/permission_matcher.dart` - Pattern matching for allow lists
- `settings/bash_command_parser.dart` - Safe command detection and parsing
- `agent_network/pages/` - TUI pages for network visualization
- `agent_network/state/agent_networks_state_notifier.dart` - TUI state management

**Flutter Runtime Integration** (`packages/flutter_runtime_mcp/`)
- MCP server for managing Flutter app lifecycle
- Tools: `flutterStart`, `flutterReload`, `flutterRestart`, `flutterStop`, `flutterScreenshot`, `flutterAct`
- Parses VM Service URIs for debugging and testing
- Vision AI integration (Moondream) for UI element detection via `flutterAct`

**Runtime AI Dev Tools** (`packages/runtime_ai_dev_tools/`)
- Flutter package injected transparently into running apps
- Service extensions for screenshots and tap simulation
- Shows blue ripple animations at tap locations

### UI Framework

Built on **nocterm** (terminal UI framework, similar to Flutter but for CLI):
- Uses Riverpod for state management
- Component-based architecture
- Pages in `lib/modules/agent_network/pages/`
- Components in `lib/components/`

## Important Patterns

### User-Defined Agents

Custom agents are loaded from `.claude/agents/*.md` files. The agent loader (`packages/vide_core/lib/agents/agent_loader.dart`) scans:
1. Project-level: `.claude/agents/` (relative to working directory)
2. User-level: `~/.claude/agents/` (optional, currently disabled)

Agents are parsed following the Claude agent specification and made available to the system.

### Agent Communication Flow

```dart
// Spawning an agent
spawnAgent(
  agentType: "implementation",
  name: "Bug Fix",
  initialPrompt: "Fix null pointer... Please message me back when complete."
)
setAgentStatus("waitingForAgent")

// Agent reports back
[MESSAGE FROM AGENT: {agent-id}] "Implementation complete! ..."

// Clean up
terminateAgent(targetAgentId: "{agent-id}", reason: "Task complete")
```

### Memory Usage Pattern

Flutter tester agents store build commands and platform preferences:

```dart
// Save for future sessions
memorySave(key: "build_command", value: "fvm flutter run -d chrome")

// Retrieve in later sessions
memoryRetrieve(key: "build_command")
```

### Git Worktree Workflow

The system encourages using git worktrees for non-trivial features:

1. Create worktree: `gitWorktreeAdd` with new branch
2. Switch session: `setSessionWorktree` to work in worktree
3. All agents spawned after this point work in the worktree
4. Merge back when ready: `gitMerge` from main worktree

## Testing Guidelines

- Tests use `test` package
- Tests should be silent when passing (use `expect()` for assertions)
- Only use `print()` for debugging, then remove it
- Do NOT inject try-catch blocks into tests (per global CLAUDE.md rules)
- Test files should directly test specific functionality

Key test areas:
- Permission matching (`test/permission_matcher_test.dart`)
- Bash command parsing (`test/modules/settings/bash_command_parser_test.dart`)
- Diff rendering and syntax highlighting (`test/utils/`)

## Session Completion Workflow

**When ending a work session**, complete the following steps:

1. **File issues for remaining work** - Use `bd create` for anything that needs follow-up
2. **Run quality gates** (if code changed):
   - `dart test` - Run all tests
   - `dart analyze` - Check for issues
   - `dart format .` - Format code
3. **Update issue status**:
   - `bd close <id>` for completed work
   - `bd update <id> --status=...` for in-progress items
4. **Verify all changes** - Ensure tests pass and code is formatted
5. **Hand off** - Provide clear context for next session

**Note:** The user handles git commits and pushes.

## Code Style

### Formatting
- Dart uses 2-space indentation and standard Dart formatting
- Run `dart format .` before committing
- Files use `lower_snake_case.dart`
- Classes use `UpperCamelCase`
- Variables/functions use `lowerCamelCase`

### Analysis Configuration

`analysis_options.yaml` excludes:
- Generated files (`**/*.g.dart`, `**/*.freezed.dart`)
- Flutter packages requiring Flutter SDK
- Packages with their own analysis config

Lint rules:
- `avoid_print: false` - Print is allowed in this CLI application

### Commit Messages

(For reference - user handles commits)
- Short, imperative, sentence case
- Examples: "Add tests for diff renderer", "Fix: Package macOS binary"
- Keep commits focused, avoid unrelated refactors

### Pull Requests

(For reference)
- Include clear summary and list of tests run
- Link related issues
- Add screenshots or terminal captures for user-facing TUI/CLI changes

### Code Generation

Uses build_runner for:
- Freezed (immutable data classes)
- JSON serialization
- Riverpod code generation

Run code generation:
```bash
# In root project
dart run build_runner build

# In vide_core package (if models are modified)
cd packages/vide_core
dart run build_runner build --delete-conflicting-outputs
```

**Note**: After modifying models in `packages/vide_core/lib/models/`, run code generation in the vide_core package to regenerate `.g.dart` and `.freezed.dart` files.

## Flutter-Specific Workflows

### Running Flutter Apps via MCP

Agents use `flutterStart` instead of running `flutter run` directly:

```dart
// Start app (returns instanceId)
flutterStart(command: "flutter run -d chrome", workingDirectory: "/path")

// Hot reload changes
flutterReload(instanceId: "...", hot: true)

// Take screenshot
flutterScreenshot(instanceId: "...")

// Interact with UI via vision AI
flutterAct(instanceId: "...", action: "tap", description: "login button")

// Stop when done
flutterStop(instanceId: "...")
```

### FVM Detection

The system automatically detects FVM (Flutter Version Management) and adjusts commands accordingly. Agents should use the MCP tools which handle this automatically.

### Static Analysis Workflow

Before running Flutter apps:
1. Run `dart analyze` via Bash
2. Fix all errors and warnings
3. Run again until clean
4. Never proceed with broken code

Do NOT use `analyze_files` MCP tool - it floods context with too much output.

## Error Handling Philosophy

Per the global CLAUDE.md rules:
- Don't inject try-catch blocks into implementation code unless re-throwing or adding context
- Don't paper over exceptions - find root causes
- Tests should not have try-catch blocks
- Example apps should not have try-catch blocks (they're happy path)

This helps surface problems quickly rather than hiding them.

## Architecture Best Practices

- **TDD (Test-Driven Development)** - write the tests first; the implementation code isn't done until the tests pass.
- **DRY (Don't Repeat Yourself)** – eliminate duplicated logic by extracting shared utilities and modules.
- **Separation of Concerns** – each module should handle one distinct responsibility.
- **Single Responsibility Principle (SRP)** – every class/module/function/file should have exactly one reason to change.
- **Clear Abstractions & Contracts** – expose intent through small, stable interfaces and hide implementation details.
- **Low Coupling, High Cohesion** – keep modules self-contained, minimize cross-dependencies.
- **Scalability & Statelessness** – design components to scale horizontally and prefer stateless services when possible.
- **Observability & Testability** – build in logging, metrics, tracing, and ensure components can be unit/integration tested.
- **KISS (Keep It Simple, Sir)** - keep solutions as simple as possible.
- **YAGNI (You're Not Gonna Need It)** – avoid speculative complexity or over-engineering.
- **Don't Swallow Errors** by catching exceptions, silently filling in required but missing values or adding timeouts when something hangs unexpectedly. All of those are exceptions that should be thrown so that the errors can be seen, root causes can be found and fixes can be applied.
- **No Placeholder Code** - we're building production code here, not toys.
- **No Comments for Removed Functionality** - the source is not the place to keep history of what's changed; it's the place to implement the current requirements only.
- **Layered Architecture** - organize code into clear tiers where each layer depends only on the one(s) below it, keeping logic cleanly separated.
- **Prefer Non-Nullable Variables** when possible; use nullability sparingly.

## Packaging and Distribution

### Homebrew Distribution

The project has a custom Homebrew tap at `Norbert515/tap`. Binaries are packaged as tarballs for Homebrew compatibility.

### Multi-Platform Builds

Binaries are built for:
- macOS (Universal binary)
- Linux (x64)
- Windows (x64)

See `.github/workflows/` for build pipeline configuration.

## Dependencies

### Core Dependencies

- `nocterm` - Terminal UI framework (custom git dependency)
- `riverpod` - State management
- `claude_sdk` - Claude Code API integration (local package)
- `flutter_runtime_mcp` - Flutter runtime management (local package)
- `freezed` / `json_serializable` - Code generation
- `sentry` - Error tracking
- `http` - HTTP client

### Local Packages

- `packages/vide_core/` - Shared business logic (models, services, MCP servers, agents)
- `packages/vide_server/` - REST API server with WebSocket streaming
- `packages/claude_sdk/` - Claude SDK client
- `packages/flutter_runtime_mcp/` - Flutter runtime MCP server
- `packages/runtime_ai_dev_tools/` - Flutter service extensions
- `packages/moondream_api/` - Moondream vision AI client

## Configuration Files

### User Settings

- `.claude/settings.local.json` - Local project settings (permissions, hooks, etc.)
- `.claude/agents/*.md` - User-defined custom agents
- `~/.vide/` - TUI global application data directory
- `~/.vide/api/` - REST API global application data directory (session isolation)

### Permission System

Permission patterns are stored in `.claude/settings.local.json` and matched against tool invocations. The system supports:
- File path patterns (glob-style)
- Bash command patterns
- Web domain patterns
- Tool name patterns

Safe commands (read-only operations like `ls`, `cat`, `git status`) are auto-approved.

## REST API Server

The `vide_server` package provides a REST API with WebSocket streaming for agent networks.

### Running the Server

```bash
cd packages/vide_server
dart run bin/vide_server.dart [--port 8080]
```

Note the port number from server output (e.g., `http://127.0.0.1:63139`).

### API Endpoints

- `GET /health` - Health check (returns "OK")
- `POST /api/v1/networks` - Create agent network
  - Body: `{"initialMessage": "...", "workingDirectory": "/path"}`
  - Returns: `{"networkId": "uuid", "mainAgentId": "uuid", "createdAt": "..."}`
- `POST /api/v1/networks/{networkId}/messages` - Send message (multi-turn conversation)
  - Body: `{"content": "Your message here"}`
- `ws://host:port/api/v1/networks/{networkId}/agents/{agentId}/stream` - Stream events via WebSocket

### WebSocket Event Types

- `connected` - WebSocket connection established
- `status` - Agent status update (e.g., "connected")
- `message` - Full user or assistant message (start of new message)
- `message_delta` - Streaming chunk of assistant message (incremental text)
- `tool_use` - Agent is using a tool
- `tool_result` - Tool execution result
- `done` - Turn complete
- `error` - Error occurred

**Streaming Behavior:**
1. `message` event when message starts
2. Multiple `message_delta` events with incremental chunks as text is generated
3. Client appends deltas to display streaming text effect

### How It Works

1. **Create a network** via `POST /api/v1/networks` - returns IDs immediately
2. **Connect to WebSocket** - triggers actual network creation (lazy initialization)
3. **Receive events** - all conversation events stream in real-time
4. **Send messages** - use `POST /api/v1/networks/{networkId}/messages` to continue conversation
5. **Process responses** - handle messages, tool use, and completion events

Network creation is lazy - happens when WebSocket connects, ensuring no events are missed.

### Testing the Server

```bash
cd packages/vide_server
dart test  # Includes end-to-end integration tests

# Run example REPL client
dart run example/client.dart -p <port>
```

**Security Warning:** Server has no authentication and is for localhost use only. Do NOT expose to internet.
