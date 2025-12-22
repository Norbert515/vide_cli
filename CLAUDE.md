# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vide CLI is an agentic terminal UI for Claude Code, built specifically for Flutter developers. It implements a multi-agent architecture where specialized agents collaborate asynchronously via message passing to accomplish development tasks.

## Development Commands

### Building and Running

```bash
# Get dependencies
dart pub get

# Compile executable locally (for testing)
dart compile exe bin/vide.dart -o vide

# Install globally (native compiled)
just install

# Run from source (development mode)
dart run bin/vide.dart
```

### Testing

```bash
# Run all tests
dart test

# Run specific test file
dart test test/permission_matcher_test.dart
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

**Agent Network** (`lib/modules/agent_network/`)
- `service/agent_network_manager.dart` - Core agent lifecycle management (spawn, message, terminate)
- `service/claude_manager.dart` - Manages ClaudeClient instances per agent
- `models/agent_network.dart` - Agent network data structures
- `state/agent_status_manager.dart` - Tracks agent status (working, waiting, idle)

**Agent Configurations** (`lib/modules/agents/`)
- `configs/` - Agent prompt configurations for each agent type
- `configs/prompt_sections/` - Reusable prompt sections (Flutter, Dart, Git workflows, etc.)
- `agent_loader.dart` - Loads user-defined agents from `.claude/agents/*.md`

**MCP Servers** (`lib/modules/mcp/`)
- `agent/agent_mcp_server.dart` - Agent spawning, messaging, status management
- `git/git_server.dart` - Git operations including worktree support
- `task_management/task_management_server.dart` - Task naming for UI display

**Memory** (`lib/modules/memory/`)
- `memory_mcp_server.dart` - Persistent key-value storage scoped to project path
- `memory_service.dart` - Stores build commands, platform choices, etc. across sessions

**Permissions** (`lib/modules/permissions/`)
- `permission_service.dart` - Manages tool invocation permissions via dialog
- `permission_scope.dart` - UI scope for permission dialogs
- Permission matching system for file operations, bash commands, web requests

**Settings** (`lib/modules/settings/`)
- `local_settings_manager.dart` - Manages `.claude/settings.local.json`
- `permission_matcher.dart` - Pattern matching for allow lists
- `bash_command_parser.dart` - Safe command detection and parsing

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

Custom agents are loaded from `.claude/agents/*.md` files. The agent loader (`lib/modules/agents/agent_loader.dart`) scans:
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

## Code Style

### Analysis Configuration

`analysis_options.yaml` excludes:
- Generated files (`**/*.g.dart`, `**/*.freezed.dart`)
- Flutter packages requiring Flutter SDK
- Packages with their own analysis config

Lint rules:
- `avoid_print: false` - Print is allowed in this CLI application

### Code Generation

Uses build_runner for:
- Freezed (immutable data classes)
- JSON serialization
- Riverpod code generation

Run code generation:
```bash
dart run build_runner build
```

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
- `claude_api` - Claude Code API integration (local package)
- `flutter_runtime_mcp` - Flutter runtime management (local package)
- `freezed` / `json_serializable` - Code generation
- `sentry` - Error tracking
- `http` - HTTP client

### Local Packages

- `packages/claude_api/` - Claude API client
- `packages/flutter_runtime_mcp/` - Flutter runtime MCP server
- `packages/runtime_ai_dev_tools/` - Flutter service extensions
- `packages/moondream_api/` - Moondream vision AI client

## Configuration Files

### User Settings

- `.claude/settings.local.json` - Local project settings (permissions, hooks, etc.)
- `.claude/agents/*.md` - User-defined custom agents
- `~/.vide/` - Global application data directory

### Permission System

Permission patterns are stored in `.claude/settings.local.json` and matched against tool invocations. The system supports:
- File path patterns (glob-style)
- Bash command patterns
- Web domain patterns
- Tool name patterns

Safe commands (read-only operations like `ls`, `cat`, `git status`) are auto-approved.
