# runtime_ai_dev_tools

Runtime AI dev tools for Flutter - service extensions for AI-assisted app testing.

## Features

This package provides service extensions that enable AI agents to interact with your Flutter application at runtime:

- **Screenshot capture**: Capture screenshots of your running Flutter app via service extension
- **Tap simulation**: Simulate tap interactions with visual feedback
- **Cross-platform support**: Works on all Flutter platforms (mobile, web, desktop)

## Getting started

Add this package to your Flutter application:

```yaml
dependencies:
  runtime_ai_dev_tools: ^0.0.1
```

## Usage

Initialize the dev tools at the very beginning of your `main()` function:

```dart
import 'package:flutter/material.dart';
import 'package:runtime_ai_dev_tools/runtime_ai_dev_tools.dart';

void main() {
  RuntimeAiDevTools.init();
  runApp(MyApp());
}
```

That's it! The service extensions will be registered and available for use.

## Service Extensions

### Screenshot Extension

**Extension name**: `ext.runtime_ai_dev_tools.screenshot`

**Parameters**: None

**Response format**:
```json
{
  "status": "success",
  "image": "base64EncodedPngString"
}
```

### Tap Extension

**Extension name**: `ext.runtime_ai_dev_tools.tap`

**Parameters**:
- `x` (string) - x coordinate
- `y` (string) - y coordinate

**Response format**:
```json
{
  "status": "success",
  "x": "123.5",
  "y": "456.7"
}
```

## Example

See the `example/` directory for a complete demo app that shows the package in action.

The example app includes:
- Home screen with navigation
- Gallery screen with interactive elements
- Form screen with various input fields

Run the example:

```bash
cd example
flutter run
```

## Technical Details

- Screenshots are captured using `RenderRepaintBoundary` at 2.0 pixel ratio
- Tap simulation uses `GestureBinding.instance.handlePointerEvent()`
- Tap visualization shows a blue ripple animation that expands and fades out
- All service extensions use `dart:developer` for registration
- Works on web with CanvasKit (default in Flutter 3.24+)

## Additional information

This package is designed to work with AI-powered testing frameworks that can interact with Flutter apps via the VM service protocol.

For issues or feature requests, please file them in the GitHub repository.
