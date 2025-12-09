# Flutter Runtime MCP Examples

This directory contains examples for testing the Flutter Runtime MCP server.

## Files

### flutter_runtime_demo.dart
Basic demo that starts the server and displays available tools.

```bash
dart run example/flutter_runtime_demo.dart
```

### manual_test.dart
Interactive HTTP/SSE client for manually testing MCP tool invocations.

```bash
dart run example/manual_test.dart
```

## Manual Test Client

The manual test client provides an interactive CLI menu for testing all Flutter Runtime MCP tools:

### Features
- **Start Flutter instance**: Launch a Flutter app with custom command and working directory
- **List instances**: View all running Flutter instances
- **Get instance info**: Get detailed information about a specific instance
- **Hot reload**: Perform hot reload on a running instance
- **Hot restart**: Perform full restart on a running instance
- **Stop instance**: Gracefully stop a running instance

### Usage Example

1. Start the test client:
```bash
dart run example/manual_test.dart
```

2. The server will start automatically on port 8081

3. Choose option 1 to start a Flutter instance:
```
Choice: 1
Enter flutter command: flutter run -d chrome
Enter working directory: /path/to/your/flutter/app
```

4. Note the returned Instance ID (UUID)

5. Use the Instance ID with other operations:
```
Choice: 4
Enter instance ID: 550e8400-e29b-41d4-a716-446655440000
```

### Implementation Details

The manual test client demonstrates:
- Direct HTTP/SSE communication with MCP servers
- JSON-RPC 2.0 message formatting
- SSE stream parsing for responses
- Session management via `Mcp-Session-Id` headers
- Interactive CLI using stdin/stdout

### Architecture

```
┌─────────────────────────────────────┐
│  Manual Test Client (manual_test)  │
│  • Interactive CLI menu             │
│  • McpHttpClient (HTTP/SSE)         │
└──────────────┬──────────────────────┘
               │ HTTP POST + SSE
               │ (JSON-RPC 2.0)
               ▼
┌─────────────────────────────────────┐
│  FlutterRuntimeServer (port 8081)  │
│  • SseServerManager                 │
│  • McpServer with tools             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Flutter Instances (managed)        │
│  • Process spawning                 │
│  • Hot reload/restart via stdin     │
│  • Output parsing (VM Service URI)  │
└─────────────────────────────────────┘
```

### Testing with a Real Flutter App

1. Create or use an existing Flutter app:
```bash
cd /path/to/your/flutter/projects
flutter create test_app
cd test_app
```

2. Run the manual test client:
```bash
dart run /path/to/parott/packages/flutter_runtime_mcp/example/manual_test.dart
```

3. Start the Flutter app through the client:
```
Choice: 1
Enter flutter command: flutter run -d chrome
Enter working directory: /path/to/your/flutter/projects/test_app
```

4. Test hot reload:
   - Make a change to `lib/main.dart`
   - Use option 4 (Hot reload) with the instance ID
   - Verify the change appears in the running app

5. Clean up:
   - Use option 6 to stop the instance
   - Use option 7 to exit the client
