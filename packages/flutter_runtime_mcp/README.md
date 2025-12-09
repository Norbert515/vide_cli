# Flutter Runtime MCP

MCP (Model Context Protocol) server for managing Flutter application runtime instances.

## Features

- **Start Flutter Apps**: Launch Flutter applications with `flutter run` commands
- **Hot Reload**: Trigger hot reload on running instances
- **Hot Restart**: Perform full restarts of running instances
- **Process Management**: Stop and manage multiple concurrent Flutter instances
- **VM Service Tracking**: Automatically parse and expose VM Service URIs
- **Instance Tracking**: UUID-based instance management for multiple concurrent apps
- **Screenshots**: Capture screenshots of running Flutter apps via VM Service
- **AI-Powered Testing**: Interact with UI elements using natural language descriptions via Moondream vision AI
- **Visual Feedback**: Blue ripple animations show tap locations when using `runtime_ai_dev_tools` package

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_runtime_mcp:
    path: ../packages/flutter_runtime_mcp
```

## Usage

### Starting the Server

```dart
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

void main() async {
  final server = FlutterRuntimeServer();
  await server.start(8081);

  print('Server running at: ${server.toClaudeConfig()}');
}
```

### MCP Tools

#### flutterStart

Start a Flutter application instance.

**Parameters:**
- `command` (required): The flutter run command (e.g., "flutter run -d chrome")
- `workingDirectory` (optional): Working directory for the Flutter project

**Returns:** UUID for the started instance

**Example:**
```json
{
  "command": "flutter run -d chrome",
  "workingDirectory": "/path/to/my/flutter/app"
}
```

#### flutterReload

Perform a hot reload or restart on a running instance.

**Parameters:**
- `instanceId` (required): UUID of the Flutter instance
- `hot` (optional, default: true): Whether to hot reload (true) or hot restart (false)

**Example:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000",
  "hot": true
}
```

#### flutterRestart

Convenience method for hot restart (full restart).

**Parameters:**
- `instanceId` (required): UUID of the Flutter instance

**Example:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### flutterStop

Stop a running Flutter instance.

**Parameters:**
- `instanceId` (required): UUID of the Flutter instance to stop

**Example:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### flutterList

List all running Flutter instances.

**Parameters:** None

**Returns:** Information about all running instances including:
- Instance ID
- Running status
- Start time
- Working directory
- Command
- VM Service URI (if available)
- Device ID (if available)

#### flutterGetInfo

Get detailed information about a specific Flutter instance.

**Parameters:**
- `instanceId` (required): UUID of the Flutter instance

**Returns:** Detailed instance information in JSON format

#### flutterScreenshot

Take a screenshot of a running Flutter instance.

**Parameters:**
- `instanceId` (required): UUID of the Flutter instance to screenshot

**Returns:** PNG image as base64-encoded ImageContent

**Example:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Note:** Requires the Flutter app to be running in debug/profile mode with VM Service available. Uses the `runtime_ai_dev_tools` package service extension if available, providing high-quality screenshots at 2x pixel ratio.

#### flutterAct

Perform an action on a Flutter UI element by describing it in natural language. Uses vision AI (Moondream) to locate elements and perform actions.

**Parameters:**
- `instanceId` (required): UUID of the Flutter instance
- `action` (required): Action to perform - "click" or "tap"
- `description` (required): Natural language description of the UI element (e.g., "login button", "email input field")

**Returns:** Success message with coordinates

**Example:**
```json
{
  "instanceId": "550e8400-e29b-41d4-a716-446655440000",
  "action": "tap",
  "description": "submit button"
}
```

**Requirements:**
- `MOONDREAM_API_KEY` environment variable must be set
- Flutter app must use the `runtime_ai_dev_tools` package for tap visualization
- Screenshots are taken at 2x devicePixelRatio and coordinates are automatically converted to logical pixels

**How it works:**
1. Takes a screenshot of the Flutter app
2. Sends screenshot to Moondream vision AI with element description
3. Receives normalized coordinates (0-1 range)
4. Converts to physical pixels based on screenshot dimensions
5. Divides by devicePixelRatio (2.0) to get logical pixels
6. Performs tap at the calculated logical pixel coordinates
7. Shows blue ripple animation at tap location (if `runtime_ai_dev_tools` is integrated)

## Implementation Details

### FlutterInstance

Each running Flutter app is wrapped in a `FlutterInstance` object that:
- Tracks the process and its output
- Parses stdout to extract VM Service URIs and device IDs
- Provides hot reload/restart functionality via stdin commands
- Handles graceful shutdown with fallback to force kill

### Command Parsing

The server intelligently parses flutter run commands, handling:
- Quoted arguments (single and double quotes)
- Multiple flags and options
- Working directory context

### Process Management

- Automatic cleanup when processes exit
- Graceful shutdown with 5-second timeout
- Force kill fallback if graceful shutdown fails
- Multiple concurrent instances supported

## Integration with runtime_ai_dev_tools

For the best testing experience with `flutterAct` and `flutterScreenshot`, integrate the `runtime_ai_dev_tools` package into your Flutter app:

### 1. Add the package to your Flutter app

```yaml
dependencies:
  runtime_ai_dev_tools:
    path: ../runtime_ai_dev_tools
```

### 2. Initialize in your main.dart

```dart
import 'package:runtime_ai_dev_tools/runtime_ai_dev_tools.dart';

void main() {
  RuntimeAiDevTools.init();  // Add this line
  runApp(const MyApp());
}
```

### 3. Benefits

- **High-quality screenshots**: 2x pixel ratio screenshots via service extensions
- **Tap visualization**: Blue ripple animations show exactly where taps occur
- **Reliable taps**: Service extension-based taps are more reliable than VM Service evaluator
- **No fallbacks needed**: All operations use proper service extensions with isolateId

## Example Workflow

```dart
// 1. Start a Flutter instance
final startResult = await server.callTool('flutterStart', {
  'command': 'flutter run -d chrome',
  'workingDirectory': '/path/to/app',
});
// Returns: Instance ID: 550e8400-e29b-41d4-a716-446655440000

// 2. Make code changes, then hot reload
await server.callTool('flutterReload', {
  'instanceId': '550e8400-e29b-41d4-a716-446655440000',
  'hot': true,
});

// 3. For major changes, hot restart
await server.callTool('flutterRestart', {
  'instanceId': '550e8400-e29b-41d4-a716-446655440000',
});

// 4. List all running instances
await server.callTool('flutterList', {});

// 5. Stop the instance when done
await server.callTool('flutterStop', {
  'instanceId': '550e8400-e29b-41d4-a716-446655440000',
});
```

## Running the Demo

```bash
cd packages/flutter_runtime_mcp
dart run example/flutter_runtime_demo.dart
```

## License

Same as parent project
