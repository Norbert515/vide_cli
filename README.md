# Parott 🦜

A terminal UI client for Claude AI built with Dart and nocterm.

## Features

- Interactive chat interface with Claude
- Real-time streaming responses  
- Tool use visualization
- Clean terminal UI with colored output
- Command-line interface for quick queries

## Usage

### Interactive Mode

Run the interactive chat interface:

```bash
dart run bin/parott.dart
```

This opens a full-screen terminal UI where you can:
- Type messages and press Enter to send
- See Claude's responses in real-time
- View tool usage and results
- Exit with Ctrl+C

### CLI Mode

For quick, one-off queries:

```bash
# Ask a default question
dart run bin/parott_cli.dart

# Ask a specific question
dart run bin/parott_cli.dart "What is the capital of France?"

# Multi-word prompts
dart run bin/parott_cli.dart Tell me about Dart programming
```

### Simple Test Interface

```bash
dart run bin/test_simple.dart
```

## Files

```
bin/
  parott.dart      - Main interactive chat interface
  parott_cli.dart  - Command-line interface
  test_simple.dart - Simple test interface with text field

lib/
  interactive_claude.dart - Full interactive chat component
  simple_claude.dart      - Simple streaming component  
  components/
    response_item.dart    - Response rendering component

claude_api/ - Claude API client package
```

## Requirements

- Dart SDK
- Claude API configuration (handled by claude_api package)