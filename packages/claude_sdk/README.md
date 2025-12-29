# Claude SDK - Dart Client for Claude Code CLI

A type-safe, stream-based Dart abstraction for the Claude Code CLI using the bidirectional control protocol. This package provides a full-featured interface for building applications that interact with Claude agents.

## Features

- 🔒 **Type-safe API** with sealed classes for exhaustive response handling
- 🌊 **Stream-based** conversation updates for real-time UI
- 🔄 **Control Protocol** for hooks and permission callbacks
- 🔧 **MCP Server Support** for custom tools
- 💬 **Session Management** with persistence and resume
- ⚡ **True Streaming** with incremental text deltas

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  claude_sdk:
    path: ./claude_sdk  # Or publish to pub.dev
```

## Requirements

- Claude CLI must be installed and available in PATH
- Dart SDK ^3.0.0

## Quick Start

### Simple Message

```dart
import 'package:claude_sdk/claude_sdk.dart';

void main() async {
  final client = await ClaudeClient.create();

  // Listen to conversation updates
  client.conversation.listen((conversation) {
    final lastMessage = conversation.messages.lastOrNull;
    if (lastMessage != null) {
      print(lastMessage.content);
    }
  });

  // Send a message
  client.sendMessage(Message(text: 'Hello, Claude!'));

  // Wait for response to complete
  await client.onTurnComplete.first;
  await client.close();
}
```

### Multi-turn Conversation

```dart
final client = await ClaudeClient.create();

// Listen to conversation updates (streaming)
client.conversation.listen((conversation) {
  print('Messages: ${conversation.messages.length}');
});

// First message
client.sendMessage(Message(text: 'What is Dart?'));
await client.onTurnComplete.first;

// Follow-up - maintains context via session
client.sendMessage(Message(text: 'Can you give an example?'));
await client.onTurnComplete.first;
```

### Custom Configuration

```dart
final client = await ClaudeClient.create(
  config: ClaudeConfig(
    model: 'claude-3-opus',
    timeout: Duration(seconds: 60),
    temperature: 0.7,
    maxTokens: 1000,
    permissionMode: 'acceptEdits',
  ),
);
```

## Response Types

The API uses sealed classes for type-safe response handling:

```dart
client.conversation.listen((conversation) {
  for (final message in conversation.messages) {
    for (final response in message.responses) {
      switch (response) {
        case TextResponse(:final content, :final isPartial):
          print(content);

        case ToolUseResponse(:final toolName, :final parameters):
          print('Tool: $toolName with $parameters');

        case ToolResultResponse(:final content, :final isError):
          print('Result: $content');

        case ErrorResponse(:final error, :final details):
          print('Error: $error - $details');

        default:
          // Handle other response types
      }
    }
  }
});
```

## Hooks and Permissions

See [CONTROL_PROTOCOL.md](docs/CONTROL_PROTOCOL.md) for full documentation on:
- Pre/Post tool use hooks
- Permission callbacks (`canUseTool`)
- Hook matchers and patterns

```dart
final client = await ClaudeClient.create(
  hooks: {
    HookEvent.preToolUse: [
      HookMatcher(
        matcher: 'Bash',
        callback: (input, toolUseId) async {
          // Block dangerous commands
          return HookOutput.deny('Command blocked');
        },
      ),
    ],
  },
  canUseTool: (toolName, input, context) async {
    // Custom permission logic
    return const PermissionResultAllow();
  },
);
```

## Running Tests

```bash
cd packages/claude_sdk
dart pub get
dart run build_runner build  # Generate serialization code
dart test
```

## API Reference

### ClaudeClient

- `sendMessage(Message)` - Send a message
- `conversation` - Stream of conversation updates
- `onTurnComplete` - Stream that emits when Claude finishes responding
- `abort()` - Stop current execution
- `close()` - Clean up resources

### ClaudeConfig

Configuration options:
- `model` - Model to use (e.g., 'claude-3-opus')
- `timeout` - Request timeout duration
- `temperature` - Response randomness (0.0-1.0)
- `maxTokens` - Maximum response tokens
- `appendSystemPrompt` - Additional system prompt
- `permissionMode` - Permission mode ('acceptEdits', etc.)
- `sessionId` - Session ID for persistence
- `workingDirectory` - Working directory for the agent

### Message

- `text` - The message text
- `attachments` - Optional file attachments

## Architecture

The package is organized into clear modules:

```
lib/
├── src/
│   ├── client/       # Core client implementation
│   ├── control/      # Control protocol (hooks, permissions)
│   ├── models/       # Data models
│   ├── protocol/     # JSON encoding/decoding
│   └── mcp/          # MCP server support
└── claude_sdk.dart   # Public API exports
```

## License

MIT