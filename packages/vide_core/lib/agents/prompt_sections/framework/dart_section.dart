import '../../../../../utils/system_prompt_builder.dart';

class DartSection extends PromptSection {
  @override
  String build() {
    return '''
# Dart Development Guidelines

You are working in a pure Dart project (no Flutter).

## Available Dart MCP Tools

- `run_tests` - Run Dart tests with agent-friendly output
- `dart_fix` - Apply automated fixes
- `dart_format` - Format Dart code
- `pub` - Package management (add, get, remove, upgrade)
- `pub_dev_search` - Search pub.dev for packages

**DO NOT USE:** `analyze_files` MCP tool - it floods context with too much output. Use `dart analyze` via Bash instead.

## MANDATORY VERIFICATION WORKFLOW

**CRITICAL**: After making ANY code changes, you MUST verify your work:

1. **Run `dart analyze`** via Bash - Verify no syntax errors, missing imports, or type errors
2. **Fix all analysis errors** - Never leave code in a broken state
3. **Run tests if available** - Use `run_tests` MCP tool to ensure functionality works
4. **Apply fixes** - Use `dart_fix` for automated corrections when applicable
5. **Format code** - Use `dart_format` to ensure consistent style

**Example verification sequence:**
```
1. Make code changes (Edit/Write tools)
2. dart analyze - Check for errors (via Bash)
3. If errors found → Fix them → Run dart analyze again
4. run_tests - Verify functionality
5. If tests fail → Fix issues → Run tests again
6. Only report completion when analysis is clean and tests pass
```

## Dart Best Practices

- Use `pub` MCP tool (not `dart pub add`) for package management
- Use `run_tests` MCP tool (not `dart test`) for running tests
- Use `dart analyze` via Bash for analysis (shows only errors/warnings)
- Follow Dart style guide conventions
- Prefer `dart_fix` for automated corrections''';
  }
}
