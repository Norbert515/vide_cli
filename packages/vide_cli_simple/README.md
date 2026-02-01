# vide_cli_simple

A simple CLI for testing and demonstrating the vide_core public API.

This is a lightweight command-line interface that showcases how to integrate with vide_core. It serves as both a testing tool and a reference implementation for building applications on top of vide_core.

## Features

- **Interactive REPL** - Chat with agents in a terminal session
- **Session Management** - List and resume saved sessions
- **Permission Handling** - Interactive permission prompts
- **Colored Output** - Terminal-aware event rendering

## Installation

This package is part of the Vide CLI monorepo.

```bash
cd packages/vide_cli_simple
dart pub get
```

## Usage

### Interactive Mode (REPL)

```bash
# Start interactive session
dart run bin/vide_cli.dart

# Start with initial message
dart run bin/vide_cli.dart "What files are in this directory?"

# Specify working directory
dart run bin/vide_cli.dart -d /path/to/project

# Use specific model
dart run bin/vide_cli.dart -m opus "Help me fix the bug"
```

### REPL Commands

| Command | Description |
|---------|-------------|
| `/help`, `/h` | Show available commands |
| `/agents`, `/a` | List agents in session |
| `/sessions`, `/s` | List all saved sessions |
| `/abort` | Abort current operation |
| `/quit`, `/q` | Exit the CLI |

### Options

```
-d, --dir          Working directory (default: current)
-m, --model        Model: sonnet, opus, haiku
    --config-dir   Configuration directory (default: ~/.vide)
-t, --team         Team to use (default: vide)
-h, --help         Show help
-v, --version      Show version
```

## Architecture

```
bin/
└── vide_cli.dart      # Entry point, argument parsing

lib/src/
├── repl.dart          # Interactive REPL loop
└── event_renderer.dart # Terminal event rendering
```

### Event Rendering

The `EventRenderer` class renders `VideEvent`s to the terminal:

- `MessageEvent` - Streaming text content
- `ToolUseEvent` - Tool invocation with parameters
- `ToolResultEvent` - Tool results (success/error)
- `StatusEvent` - Agent status changes
- `AgentSpawnedEvent` - New agent notifications
- `AgentTerminatedEvent` - Agent removal
- `PermissionRequestEvent` - Interactive permission prompts
- `TurnCompleteEvent` - Turn completion with stats
- `ErrorEvent` - Error messages

## Example Session

```
$ dart run bin/vide_cli.dart "List the files"

Starting session...

I'll list the files in the current directory.

[Tool: Bash] ls -la
total 24
drwxr-xr-x  5 user  staff   160 Jan 17 10:00 .
drwxr-xr-x  8 user  staff   256 Jan 17 09:00 ..
-rw-r--r--  1 user  staff   234 Jan 17 10:00 pubspec.yaml
drwxr-xr-x  3 user  staff    96 Jan 17 10:00 lib
drwxr-xr-x  3 user  staff    96 Jan 17 10:00 bin

--- Turn complete (1,234 tokens) ---

> /agents
Agents (1):
  Main Agent (main) - ✓ idle

> /quit
Goodbye!
```

## As a Reference Implementation

This CLI demonstrates key vide_core integration patterns:

**Creating a session:**
```dart
final core = VideCore(VideCoreConfig());
final session = await core.startSession(VideSessionConfig(
  workingDirectory: '/path/to/project',
  initialMessage: 'Hello',
));
```

**Handling events:**
```dart
session.events.listen((event) {
  switch (event) {
    case MessageEvent e:
      stdout.write(e.content);
    case PermissionRequestEvent e:
      session.respondToPermission(e.requestId, allow: true);
    // ... handle other events
  }
});
```

## Dependencies

- `vide_core` - Core business logic
- `args` - Command-line argument parsing

## Related Packages

- `vide_core` - Core multi-agent system
- `vide_server` - Full REST API server (runs as daemon)
