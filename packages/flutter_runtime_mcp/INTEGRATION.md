# Flutter Runtime MCP - Integration Complete ✓

## Summary

The Flutter Runtime MCP server has been successfully created and integrated into the Vide CLI agent system.

## What Was Created

### 1. Package Structure
```
packages/flutter_runtime_mcp/
├── lib/
│   ├── flutter_runtime_mcp.dart          # Main export
│   └── src/
│       ├── flutter_instance.dart          # Flutter process wrapper
│       └── flutter_runtime_server.dart    # MCP server implementation
├── example/
│   └── flutter_runtime_demo.dart          # Demo/documentation
├── pubspec.yaml                           # Package dependencies
└── README.md                              # Package documentation
```

### 2. Core Components

#### FlutterInstance (`lib/src/flutter_instance.dart`)
- Wraps a Flutter process with UUID tracking
- Parses stdout to extract VM Service URI and device ID
- Provides `hotReload()` and `hotRestart()` methods
- Handles graceful shutdown with force-kill fallback
- Streams output for monitoring

#### FlutterRuntimeServer (`lib/src/flutter_runtime_server.dart`)
- MCP server extending `McpServerBase`
- Manages multiple concurrent Flutter instances
- 6 MCP tools available to agents:
  - `mcp__flutter-runtime__flutterStart` - Start instance, returns UUID
  - `mcp__flutter-runtime__flutterReload` - Hot reload or restart
  - `mcp__flutter-runtime__flutterRestart` - Convenience for hot restart
  - `mcp__flutter-runtime__flutterStop` - Stop instance
  - `mcp__flutter-runtime__flutterList` - List all running instances
  - `mcp__flutter-runtime__flutterGetInfo` - Get detailed instance info

## Integration Points

### 1. Main Application (`pubspec.yaml`)
```yaml
dependencies:
  flutter_runtime_mcp:
    path: ./packages/flutter_runtime_mcp
```

### 2. ClaudeManager (`lib/service/claude_manager.dart`)

**Import (Line 13):**
```dart
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
```

**Feature Flag (Line 87-88):**
```dart
// Flutter Runtime MCP settings
static const bool enableFlutterRuntime = true;
```

**Server Instantiation (Lines 175-179 in `_createClient()`):**
```dart
// Add Flutter Runtime server if enabled
if (enableFlutterRuntime && !useMockClient) {
  final flutterRuntimeServer = FlutterRuntimeServer();
  mcpServers.add(flutterRuntimeServer);
}
```

## How It Works

### Automatic Integration Flow

1. **Initialization**
   - When `ClaudeManager._createClient()` is called
   - `FlutterRuntimeServer` is instantiated (if `enableFlutterRuntime = true`)
   - Added to `mcpServers` list

2. **Server Startup**
   - `ClaudeClient._initialize()` starts all MCP servers
   - `PortManager.findAvailablePort()` assigns a free port
   - Server binds to `http://localhost:<port>/sse`
   - Tools become available to Claude Code

3. **Configuration**
   - `ProcessManager.getMcpArgs()` generates config
   - Creates temporary JSON: `{"mcpServers": {"flutter-runtime": {"type": "sse", "url": "..."}}}`
   - Passes to Claude Code: `--mcp-config /tmp/vide_mcp_config_*.json`
   - Allows tools: `--allowed-tools mcp__flutter-runtime__*`

4. **Runtime**
   - Agents can call tools: `mcp__flutter-runtime__flutterStart`
   - Requests flow: Claude Code → SSE → McpServer → Tool callback
   - Responses flow back through same chain

5. **Cleanup**
   - Config file auto-deleted after 10 seconds
   - Servers stop when conversation ends
   - All running Flutter instances are gracefully terminated

## Available Tools (Agent Perspective)

### mcp__flutter-runtime__flutterStart
Start a Flutter application instance.

**Parameters:**
```json
{
  "command": "flutter run -d chrome",
  "workingDirectory": "/path/to/flutter/app"  // optional
}
```

**Returns:**
```
Flutter instance started successfully!

Instance ID: 550e8400-e29b-41d4-a716-446655440000
Working Directory: /path/to/flutter/app
Command: flutter run -d chrome

Use this ID to interact with the instance (reload, restart, stop).
```

### mcp__flutter-runtime__flutterReload
Perform hot reload or restart.

**Parameters:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000",
  "hot": true  // true=reload, false=restart
}
```

### mcp__flutter-runtime__flutterRestart
Convenience for hot restart.

**Parameters:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### mcp__flutter-runtime__flutterStop
Stop a running instance.

**Parameters:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### mcp__flutter-runtime__flutterList
List all running instances.

**Parameters:** None

**Returns:** List of all instances with status, VM Service URIs, device IDs, etc.

### mcp__flutter-runtime__flutterGetInfo
Get detailed info about specific instance.

**Parameters:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Testing

### Integration Test
Location: `test/flutter_runtime_integration_test.dart`

Run with:
```bash
dart test test/flutter_runtime_integration_test.dart
```

**All tests pass ✓**

### Demo
Location: `packages/flutter_runtime_mcp/example/flutter_runtime_demo.dart`

Run with:
```bash
cd packages/flutter_runtime_mcp
dart run example/flutter_runtime_demo.dart
```

## Example Usage Workflow

```dart
// Agent workflow:
// 1. Start Flutter app
await callTool('mcp__flutter-runtime__flutterStart', {
  'command': 'flutter run -d chrome',
  'workingDirectory': '/path/to/app',
});
// → Returns UUID: "abc-123-..."

// 2. User makes code changes

// 3. Hot reload
await callTool('mcp__flutter-runtime__flutterReload', {
  'instanceId': 'abc-123-...',
  'hot': true,
});

// 4. For major changes, hot restart
await callTool('mcp__flutter-runtime__flutterRestart', {
  'instanceId': 'abc-123-...',
});

// 5. Check all running instances
await callTool('mcp__flutter-runtime__flutterList', {});

// 6. Stop when done
await callTool('mcp__flutter-runtime__flutterStop', {
  'instanceId': 'abc-123-...',
});
```

## Configuration

### Enable/Disable
Edit `lib/service/claude_manager.dart`:
```dart
static const bool enableFlutterRuntime = true;  // Set to false to disable
```

### Port Range
Automatic port allocation uses range 8080-9100 (via `PortManager`).

## Technical Details

### Process Management
- Command parsing handles quoted arguments
- Stdout/stderr streaming for real-time monitoring
- Automatic VM Service URI extraction via regex
- Graceful shutdown with 5-second timeout + force-kill fallback
- Process exit code tracking and auto-cleanup

### Multiple Instances
- UUID-based tracking allows concurrent Flutter apps
- Each instance maintains separate process, output streams, and state
- No limit on concurrent instances (within system resources)

### Security
- Only starts when `!useMockClient` (not in test mode)
- No automatic push/deploy capabilities
- Local execution only
- Graceful shutdown prevents orphaned processes

## Status

✅ **Implementation Complete**
✅ **Integration Complete**
✅ **Tests Passing**
✅ **Documentation Complete**

The Flutter Runtime MCP is now fully integrated and available to all Vide CLI agents!

## Future Enhancements

Potential improvements:
- Add support for Flutter DevTools integration
- Stream real-time logs to agent
- Support for custom Flutter commands (build, test, etc.)
- Device discovery and selection
- Performance profiling integration
- Breakpoint debugging support via VM Service

## Related Files

- Main integration: `lib/service/claude_manager.dart`
- Package source: `packages/flutter_runtime_mcp/`
- Tests: `test/flutter_runtime_integration_test.dart`
- Example: `packages/flutter_runtime_mcp/example/flutter_runtime_demo.dart`
