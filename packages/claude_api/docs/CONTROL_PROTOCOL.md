# Claude Code Control Protocol Implementation

This document describes the bidirectional control protocol implementation for the Claude Code SDK in Dart, based on reverse-engineering the official Python and TypeScript SDKs.

## Overview

The Control Protocol enables bidirectional communication between the SDK and Claude CLI, allowing:
- **Hooks** - Intercept and control tool execution
- **Permission callbacks** - Programmatic permission decisions
- **In-process MCP servers** - Custom tools defined in Dart
- **Dynamic configuration** - Change settings mid-session

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Dart SDK                                 │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  ControlProtocol                         │    │
│  │  • Handles control_request from CLI                      │    │
│  │  • Sends control_response back                           │    │
│  │  • Routes hook callbacks                                 │    │
│  │  • Manages permission decisions                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                    stdin/stdout (JSONL)                          │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Claude CLI Process                     │    │
│  │  • Sends hook_callback requests                          │    │
│  │  • Sends can_use_tool requests                           │    │
│  │  • Waits for SDK decisions                               │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Status

### Control Requests (CLI → SDK)

| Request Type | Status | Notes |
|--------------|--------|-------|
| `can_use_tool` | ✅ Complete | Permission requests before tool execution |
| `hook_callback` | ✅ Complete | Hook event notifications |
| `mcp_message` | ⚠️ Skeleton | Basic structure, needs full MCP routing |

### Control Commands (SDK → CLI)

| Command | Status | Notes |
|---------|--------|-------|
| `initialize` | ✅ Complete | Register hooks with CLI |
| `interrupt` | ✅ Complete | Stop current execution |
| `set_permission_mode` | ✅ Complete | Change permission mode |
| `rewind_files` | ✅ Complete | Restore files to previous state |
| `set_model` | ❌ Missing | Dynamic model change |
| `set_max_thinking_tokens` | ❌ Missing | Adjust thinking limits |

### Hook Events

| Event | Status | Description |
|-------|--------|-------------|
| `PreToolUse` | ✅ Complete | Before tool execution |
| `PostToolUse` | ✅ Complete | After tool execution |
| `UserPromptSubmit` | ✅ Complete | When user sends a prompt |
| `Stop` | ✅ Complete | Session stop event |
| `SubagentStop` | ✅ Complete | Subagent stop event |
| `PreCompact` | ✅ Complete | Before context compaction |

### Hook Features

| Feature | Status | Notes |
|---------|--------|-------|
| Sync hooks | ✅ Complete | Standard hook execution |
| Hook matchers | ✅ Complete | Filter by tool name pattern |
| `permissionDecision` | ✅ Complete | allow/deny/ask |
| `updatedInput` | ✅ Complete | Modify tool parameters |
| `systemMessage` | ✅ Complete | Inject context |
| `continue: false` | ✅ Complete | Stop session |
| Async hooks | ❌ Missing | `async: true` for deferred results |
| Hook timeouts | ⚠️ Partial | Config exists, enforcement missing |

### Permission Callbacks

| Feature | Status | Notes |
|---------|--------|-------|
| `canUseTool` callback | ✅ Complete | Custom permission logic |
| `PermissionResultAllow` | ✅ Complete | Allow with optional modifications |
| `PermissionResultDeny` | ✅ Complete | Deny with message |
| `updatedInput` | ✅ Complete | Modify tool input |
| `updatedPermissions` | ✅ Complete | Add permission rules |
| `interrupt` | ✅ Complete | Stop session on deny |

### Query Methods

| Method | Status | Notes |
|--------|--------|-------|
| `sendUserMessage()` | ✅ Complete | Send text messages |
| `sendUserMessageWithContent()` | ✅ Complete | Send with attachments |
| `interrupt()` | ✅ Complete | Stop execution |
| `setPermissionMode()` | ✅ Complete | Change permission mode |
| `rewindFiles()` | ✅ Complete | File state rollback |
| `setModel()` | ❌ Missing | Change model |
| `setMaxThinkingTokens()` | ❌ Missing | Adjust thinking |
| `supportedModels()` | ❌ Missing | List available models |
| `supportedCommands()` | ❌ Missing | List slash commands |
| `mcpServerStatus()` | ❌ Missing | MCP health check |
| `accountInfo()` | ❌ Missing | Account details |

### MCP Server Integration

| Feature | Status | Notes |
|---------|--------|-------|
| Register SDK MCP servers | ⚠️ Skeleton | Structure exists |
| Route `mcp_message` | ⚠️ Skeleton | Basic routing only |
| `initialize` handling | ⚠️ Skeleton | Returns stub response |
| `tools/list` handling | ❌ Missing | Need tool discovery |
| `tools/call` handling | ❌ Missing | Need tool execution |
| Tool schema generation | ❌ Missing | From Dart types |
| `@tool` decorator equivalent | ❌ Missing | Declarative tool definition |

---

## Usage

### Basic Usage with Hooks

```dart
import 'package:claude_api/claude_api.dart';

final client = await ClaudeClient.create(
  config: const ClaudeConfig(
    workingDirectory: '/path/to/project',
  ),
  hooks: {
    HookEvent.preToolUse: [
      HookMatcher(
        matcher: 'Bash',
        callback: (input, toolUseId) async {
          if (input is PreToolUseHookInput) {
            final command = input.toolInput['command'] as String? ?? '';

            // Block dangerous commands
            if (command.contains('rm -rf /')) {
              return HookOutput.deny('Dangerous command blocked');
            }
          }
          return HookOutput.allow();
        },
      ),
    ],
  },
);

// Send a message
client.sendMessage(Message(text: 'List files in the current directory'));

// Listen to responses
client.conversation.listen((conversation) {
  print(conversation.messages.last);
});
```

### Permission Callback

```dart
final client = await ClaudeClient.create(
  canUseTool: (toolName, input, context) async {
    // Log all tool usage
    print('Tool: $toolName, Input: $input');

    // Block specific tools
    if (toolName == 'WebSearch') {
      return PermissionResultDeny(
        message: 'Web search disabled',
      );
    }

    // Allow with modifications
    if (toolName == 'Write') {
      return PermissionResultAllow(
        updatedInput: {
          ...input,
          'file_path': '/safe/path${input['file_path']}',
        },
      );
    }

    return const PermissionResultAllow();
  },
);
```

### Hook Input Types

```dart
// PreToolUse - before tool execution
if (input is PreToolUseHookInput) {
  print('Tool: ${input.toolName}');
  print('Input: ${input.toolInput}');
}

// PostToolUse - after tool execution
if (input is PostToolUseHookInput) {
  print('Tool: ${input.toolName}');
  print('Result: ${input.toolResponse}');
}

// UserPromptSubmit - user sends message
if (input is UserPromptSubmitHookInput) {
  print('Prompt: ${input.prompt}');
}

// Stop - session ending
if (input is StopHookInput) {
  print('Stop active: ${input.stopHookActive}');
}

// PreCompact - context compaction
if (input is PreCompactHookInput) {
  print('Trigger: ${input.trigger}'); // 'manual' or 'auto'
}
```

### Hook Output Options

```dart
// Allow the operation
return HookOutput.allow();

// Deny with feedback to Claude
return HookOutput.deny('Reason shown to Claude');

// Stop the entire session
return HookOutput.stop('Session terminated');

// Allow with modifications
return HookOutput(
  hookSpecificOutput: HookSpecificOutput(
    hookEventName: 'PreToolUse',
    permissionDecision: PermissionDecision.allow,
    updatedInput: {'modified': 'parameters'},
  ),
);

// Inject context into conversation
return HookOutput(
  systemMessage: 'Important: All operations are being logged.',
);
```

---

## Protocol Details

### Message Format

All messages are JSON Lines (one JSON object per line).

#### Control Request (CLI → SDK)

```json
{
  "type": "control_request",
  "request_id": "req_123",
  "request": {
    "subtype": "hook_callback",
    "callback_id": "hook_0",
    "tool_use_id": "toolu_abc",
    "input": {
      "hook_event_name": "PreToolUse",
      "session_id": "session_xyz",
      "tool_name": "Bash",
      "tool_input": {"command": "ls -la"}
    }
  }
}
```

#### Control Response (SDK → CLI)

```json
{
  "type": "control_response",
  "response": {
    "subtype": "success",
    "request_id": "req_123",
    "response": {
      "continue": true,
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow"
      }
    }
  }
}
```

#### User Message (SDK → CLI)

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": "Hello, Claude!"
  }
}
```

---

## Roadmap

### Phase 1 - Core Protocol (✅ Complete)
- [x] Hook callback handling
- [x] Permission callbacks
- [x] Basic control commands
- [x] User message sending

### Phase 2 - Extended Commands (🚧 In Progress)
- [ ] `set_model` command
- [ ] `set_max_thinking_tokens` command
- [ ] Query methods (supportedModels, etc.)

### Phase 3 - MCP Integration (📋 Planned)
- [ ] Full MCP message routing
- [ ] Tool registration API
- [ ] Tool schema generation
- [ ] Decorator-style tool definition

### Phase 4 - Advanced Features (📋 Planned)
- [ ] Async hooks support
- [ ] Hook timeout enforcement
- [ ] Cancel request handling

---

## References

- [Claude Agent SDK Python](https://github.com/anthropics/claude-agent-sdk-python)
- [Claude Agent SDK TypeScript](https://github.com/anthropics/claude-agent-sdk-typescript)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [SDK Hooks Documentation](https://platform.claude.com/docs/en/agent-sdk/hooks)

---

## File Structure

```
packages/claude_api/lib/src/control/
├── control.dart           # Export barrel
├── control_types.dart     # Hook types, callbacks, enums
├── control_messages.dart  # Request/response message classes
└── control_protocol.dart  # Main protocol handler
```
