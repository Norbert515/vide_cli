import '../../../../../utils/system_prompt_builder.dart';

class NoctermSection extends PromptSection {
  @override
  String build() {
    return '''
# Nocterm TUI Development Guidelines

You are working in a Nocterm-based Terminal User Interface (TUI) project.

## Nocterm Framework Understanding

Nocterm is a reactive TUI framework for Dart that provides:
- Component-based architecture similar to Flutter
- Reactive state management
- Terminal rendering and layout
- Keyboard input handling
- ANSI color and styling support

## Nocterm Best Practices

- Components extend `Component` base class
- Use `State` for reactive state management
- Keyboard handlers use `KeyboardEvent` patterns
- Layout uses Row/Column/Container patterns similar to Flutter
- Terminal rendering is handled by the framework
- Debug output should avoid `print()` to not interfere with TUI rendering

## Common Patterns

- Check `lib/src/framework/` for core framework code
- Check `lib/src/components/` for reusable components
- Check `example/` directory for usage examples
- State updates trigger automatic re-renders
- Component lifecycle: `build()`, `didMount()`, `didUpdate()`, `dispose()`''';
  }
}
