# Flutter Runtime MCP - TUI Test Application

An interactive Terminal User Interface (TUI) application for testing and interacting with the Flutter Runtime MCP package.

## Features

- 📋 **List Running Instances** - View all active Flutter instances with status, device, and uptime
- 🚀 **Start New Instances** - Launch Flutter applications with custom commands and working directories
- 🔄 **Hot Reload** - Trigger hot reload on running instances
- 🔃 **Hot Restart** - Perform full hot restart
- 📺 **Real-Time Output** - View stdout and stderr from Flutter processes
- 📸 **Screenshots** - Capture screenshots of running Flutter apps (requires VM Service)
- 🎛️ **Instance Details** - View detailed information about each instance
- ⏹️ **Stop Instances** - Gracefully stop running Flutter applications

## Installation

1. Navigate to the TUI app directory:
```bash
cd packages/flutter_runtime_mcp/tui_test_app
```

2. Get dependencies:
```bash
dart pub get
```

## Usage

Run the TUI application:

```bash
dart run bin/flutter_runtime_tui.dart
```

Or make it executable and run directly:

```bash
chmod +x bin/flutter_runtime_tui.dart
./bin/flutter_runtime_tui.dart
```

## Controls

### Main Menu
- `l` - List/refresh instances
- `s` - Start new Flutter instance
- `1-9` - Select instance by number
- `r` - Refresh view
- `q` - Quit application

### Instance Details View
- `r` - Hot Reload
- `R` - Hot Restart (capital R)
- `o` - View Output
- `s` - Take Screenshot
- `k` - Stop Instance (kill)
- `b` - Back to main menu
- `q` - Quit application

### Output View
- `b` - Back to instance details
- `q` - Quit application

## Workflow Examples

### Example 1: Start and Monitor a Flutter App

1. Launch the TUI: `dart run bin/flutter_runtime_tui.dart`
2. Press `s` to start a new instance
3. Enter command: `flutter run -d chrome`
4. Enter working directory (or press Enter for current directory)
5. Wait for Flutter to start
6. View instance details automatically
7. Press `o` to see real-time output

### Example 2: Hot Reload Development Loop

1. Start the TUI and launch a Flutter instance (see Example 1)
2. Make changes to your Flutter code in another terminal/editor
3. In the TUI, press `r` to trigger hot reload
4. See the changes instantly in your running app
5. Repeat steps 2-4 for iterative development

### Example 3: Take Screenshots

1. Start a Flutter instance on a device with display (chrome, macos, etc.)
2. Navigate to instance details (select instance from main menu)
3. Wait a few seconds for the app to fully render
4. Press `s` to take a screenshot
5. Find the screenshot in the current directory: `screenshot_<timestamp>.png`

### Example 4: Manage Multiple Instances

1. Start the TUI
2. Press `s` and start first instance (e.g., `flutter run -d chrome`)
3. Press `b` to go back to main menu
4. Press `s` and start second instance (e.g., `flutter run -d macos`)
5. Press `l` to see all running instances
6. Press `1` or `2` to switch between instances
7. Control each instance independently

## Starting Flutter Instances

When starting a new instance, you can use any valid Flutter command:

```bash
# Chrome browser
flutter run -d chrome

# macOS desktop
flutter run -d macos

# iOS simulator (specific device)
flutter run -d "iPhone 15 Pro"

# Android emulator
flutter run -d emulator-5554

# With additional flags
flutter run -d chrome --profile
flutter run -d macos --dart-define=ENV=dev
```

## Screenshots

Screenshots require:
- Flutter app running in debug or profile mode (not release)
- VM Service available (automatically detected)
- App fully rendered (wait a few seconds after startup)

Screenshot files are saved in the current directory with format:
```
screenshot_<timestamp>.png
```

## Troubleshooting

### Issue: "Instance not found"
**Solution**: The instance may have crashed. Check the output view for errors, or return to main menu and refresh the instance list.

### Issue: Screenshot returns "VM Service may not be available"
**Solution**:
- Wait a few seconds after starting the app for VM Service to initialize
- Ensure app is running in debug mode (not `--release`)
- Check instance details to verify VM Service URI is present

### Issue: Hot Reload not working
**Solution**:
- Verify the instance is still running (check status in details view)
- Some changes require hot restart instead of hot reload
- Check output view for any Flutter errors

### Issue: Can't start instance
**Solution**:
- Verify Flutter is installed: `flutter doctor`
- Check that the working directory contains a valid Flutter project
- Ensure the specified device is available: `flutter devices`

## Architecture

The TUI application consists of:

- **`bin/flutter_runtime_tui.dart`** - Entry point that initializes the MCP server
- **`lib/tui_app.dart`** - Main TUI logic with views and input handling

### Views

1. **Main Menu** - Lists all running instances with quick actions
2. **Instance Details** - Shows detailed information and control options
3. **Start Form** - Interactive form for launching new instances
4. **Output View** - Displays real-time stdout/stderr from Flutter process

### Input Handling

The TUI uses raw stdin mode for responsive keyboard input:
- Single-key commands for quick actions
- No need to press Enter for most operations
- Context-sensitive controls based on current view

## Integration with Flutter Runtime MCP

The TUI directly uses the `FlutterRuntimeServer` class:

```dart
// Create server
final server = FlutterRuntimeServer();

// Start on available port
await server.start(8080);

// Access instances
final instances = server.getAllInstances();
final instance = server.getInstance(instanceId);

// Control instances
await instance.hotReload();
await instance.hotRestart();
await instance.screenshot();
await instance.stop();

// Monitor output
instance.output.listen((line) => print(line));
instance.errors.listen((line) => print('[ERROR] $line'));
```

## Development

### Running in Development Mode

```bash
# From tui_test_app directory
dart run bin/flutter_runtime_tui.dart
```

### Testing with the Sample App

Use the included test app for quick testing:

```bash
# In the TUI, press 's' and enter:
flutter run -d chrome

# For working directory, enter:
../test_app
```

### Adding New Features

1. Add new input handlers in `_handleXXXInput()` methods
2. Create new view methods (e.g., `_showXXXView()`)
3. Update the `_currentView` state management
4. Add keyboard shortcuts to the relevant view

## Requirements

- Dart SDK `^3.8.0`
- Flutter SDK (for running Flutter apps)
- Terminal with ANSI support (for colors and formatting)

## License

Same as the parent Parott project.

## Contributing

This TUI is part of the Flutter Runtime MCP package. For issues or contributions, please refer to the main package repository.

## Related Documentation

- [Flutter Runtime MCP Package](../README.md)
- [Integration Guide](../INTEGRATION.md)
- [Example Scripts](../example/)
