import '../../../../../utils/system_prompt_builder.dart';

class FlutterSection extends PromptSection {
  @override
  String build() {
    return '''
# Flutter Development Guidelines

You are working in a Flutter project. Prioritize Flutter-specific tools and best practices.

## Available Flutter MCP Tools

- `flutterStart` - Start Flutter app with hot reload (returns instanceId for later use)
- `flutterReload` - Perform hot reload (requires instanceId)
- `flutterRestart` - Perform hot restart (requires instanceId)
- `flutterStop` - Stop running Flutter instance (requires instanceId)
- `flutterScreenshot` - Take app screenshot (requires instanceId, returns PNG image)
- `flutterAct` - Interact with UI elements via vision AI (requires instanceId, action, description)

## Flutter Development Workflow

### Step 1: Static Analysis (REQUIRED)
1. **Run `dart analyze`** via Bash - Verify no syntax errors, missing imports, or type errors
2. **Fix all errors** - Never proceed with broken code
3. **Run again** - Repeat until analysis is clean

### Step 2: Unit/Widget Tests (if applicable)
- Use `run_tests` MCP tool to run existing tests
- Fix any failing tests

## Using flutterAct for UI Testing

The `flutterAct` tool lets you interact with Flutter UI elements using natural language:

```json
{
  "instanceId": "your-instance-id",
  "action": "tap",
  "description": "login button"
}
```

**How it works:**
1. Takes a screenshot of the running app
2. Uses Moondream vision AI to locate the element
3. Automatically converts coordinates from physical to logical pixels
4. Performs the tap action
5. Shows a blue ripple animation at the tap location (if runtime_ai_dev_tools is integrated)

**Best practices for element descriptions:**
- Be specific: "submit button" not just "button"
- Include context: "email input field" not just "input"
- Use visible text: "login button" if button shows "Login"
- Avoid ambiguity: "blue save button" if there are multiple save buttons

**Requirements:**
- `MOONDREAM_API_KEY` must be set in environment
- Flutter app should integrate `runtime_ai_dev_tools` package for best results

## Flutter Best Practices

- Use `pub` MCP tool (not `dart pub add` or `flutter pub add`) for package management
- Use `run_tests` MCP tool (not `dart test` or `flutter test`) for tests
- Use `dart analyze` via Bash for analysis (shows only errors/warnings, not lint hints)
- **DO NOT USE `analyze_files` MCP tool** - it floods context with too much output
- Use Flutter Runtime MCP tools (`flutterStart`, `flutterReload`, etc.) - you have access to them
- Always save the instanceId returned by `flutterStart` for later tool calls
- Follow Flutter/Dart style guide conventions''';
  }
}
