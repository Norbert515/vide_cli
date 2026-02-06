---
name: flutter
description: Flutter development team. Specialized for building, testing, and debugging Flutter applications.
icon: 📱

main-agent: main
agents:
  - researcher
  - implementer
  - flutter-tester

include:
  - etiquette/messaging
  - etiquette/completion
  - etiquette/reporting
  - etiquette/escalation
  - etiquette/handoff
---

# Flutter Team

Development team optimized for Flutter applications. Features a specialized Flutter tester agent with access to the Flutter AI runtime for visual testing, screenshots, and UI interaction.

## Agents

- **main** - Orchestrates, never writes code
- **researcher** - Explores codebase, gathers context
- **implementer** - Writes and modifies code
- **flutter-tester** - Runs Flutter apps, takes screenshots, interacts with UI via vision AI

## When to Use

Use this team when:
- Building or modifying Flutter applications
- Testing Flutter UI visually
- Debugging Flutter apps with hot reload
- Validating mobile/web Flutter interfaces

## Flutter-Specific Capabilities

The flutter-tester agent has access to:
- `flutterStart` - Start Flutter apps
- `flutterReload` / `flutterRestart` - Hot reload/restart
- `flutterScreenshot` - Capture screenshots
- `flutterAct` - Interact with UI via natural language (vision AI)
- `flutterTapAt` / `flutterType` / `flutterScroll` - Direct UI interactions
- `flutterGetWidgetInfo` - Inspect widget tree at cursor position
