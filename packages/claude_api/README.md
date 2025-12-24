# Claude API - Dart Client for Claude Code CLI

A type-safe, stream-based Dart abstraction for the Claude Code Headless CLI API. This package provides an easy-to-use interface for interacting with Claude through the command-line interface.

## Features

- 🔒 **Type-safe API** with sealed classes for exhaustive response handling
- 🌊 **Stream-based** communication for real-time responses
- 🔄 **Automatic process management** of the Claude CLI
- 🧪 **Built-in testing support** with mock client
- 💬 **Conversation management** with history tracking
- ⚡ **Async/await and Stream patterns** using modern Dart features

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  claude_api:
    path: ./claude_api  # Or publish to pub.dev
```

## Requirements

- Claude CLI must be installed and available in PATH
- Dart SDK ^3.0.0

## Quick Start

### Simple Message

```dart
import 'package:claude_api/claude_api.dart';

void main() async {
  final client = await ClaudeClient.create();
  
  await for (final response in client.sendMessage("Hello, Claude!")) {
    if (response is TextResponse) {
      print(response.content);
    }
  }
  
  await client.close();
}
```

### Multi-turn Conversation

```dart
final client = await ClaudeClient.create();
final conversation = client.startConversation();

// First message
await for (final response in conversation.send("What is Dart?")) {
  // Handle responses
}

// Follow-up - maintains context
await for (final response in conversation.send("Can you give an example?")) {
  // Handle responses
}
```

### Custom Configuration

```dart
final client = await ClaudeClient.create(
  config: ClaudeConfig(
    model: 'claude-3-opus',
    timeout: Duration(seconds: 60),
    temperature: 0.7,
    maxTokens: 1000,
    verbose: true,
  ),
);
```

## Response Types

The API uses sealed classes for type-safe response handling:

```dart
await for (final response in client.sendMessage("Hello")) {
  switch (response) {
    case TextResponse(:final content, :final isPartial):
      print(content);
      
    case ToolUseResponse(:final toolName, :final parameters):
      print('Tool: $toolName with $parameters');
      
    case ErrorResponse(:final error, :final details):
      print('Error: $error - $details');
      
    case CompletionResponse(:final stopReason):
      print('Completed: $stopReason');
      
    case StatusResponse(:final status):
      print('Status: $status');
      
    default:
      // Handle other response types
  }
}
```

## Testing

### Using Mock Client

```dart
final client = MockClaudeClientBuilder()
    .withTextResponse('Hello from mock!')
    .withToolUse('calculator', {'operation': 'add', 'a': 5, 'b': 3})
    .withError('Test error')
    .build();

// Use mock client exactly like real client
await for (final response in client.sendMessage("Test")) {
  // Handle responses
}
```

### Running Tests

```bash
cd claude_api
dart pub get
dart run build_runner build  # Generate serialization code
dart test
```

## Examples

See the `example/` directory for complete examples:

- `simple_chat.dart` - Interactive chat interface
- `conversation_example.dart` - Multi-turn conversation
- `mock_example.dart` - Testing with mock client

Run examples:

```bash
dart run example/simple_chat.dart
```

## API Reference

### ClaudeClient

- `sendMessage(String)` - Send a simple text message
- `send(Message)` - Send a message with attachments
- `startConversation()` - Start a multi-turn conversation
- `close()` - Clean up resources

### ClaudeConfig

Configuration options:
- `model` - Model to use (e.g., 'claude-3-opus')
- `timeout` - Request timeout duration
- `retryAttempts` - Number of retry attempts
- `temperature` - Response randomness (0.0-1.0)
- `maxTokens` - Maximum response tokens
- `systemPrompt` - System prompt to use
- `verbose` - Enable verbose output

### Message

- `text` - The message text
- `attachments` - Optional file attachments
- `metadata` - Optional metadata

## Architecture

The package is organized into clear modules:

```
lib/
├── src/
│   ├── client/       # Core client implementation
│   ├── models/       # Data models
│   ├── protocol/     # JSON encoding/decoding
│   └── testing/      # Mock implementations
└── claude_api.dart   # Public API exports
```

## Error Handling

The client handles various error scenarios through `ErrorResponse` - API-level errors returned in the response stream.

## Contributing

Contributions are welcome! Please ensure:
1. All tests pass
2. Code follows Dart conventions
3. New features include tests

## License

MIT