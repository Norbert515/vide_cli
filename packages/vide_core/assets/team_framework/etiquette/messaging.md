---
name: messaging
description: Core rules for agent-to-agent messaging
applies-to: all
---

# Messaging Protocol

Agents communicate via `sendMessageToAgent`. This protocol ensures messages are clear, actionable, and properly received.

## The Golden Rule

**If someone asks you to report back, you MUST call `sendMessageToAgent`.**

Writing a summary in your response text is NOT the same as sending a message. The other agent will NOT receive it unless you invoke the tool.

## Message Lifecycle

```
Agent A spawns Agent B
    ↓
Agent B receives: "[SPAWNED BY AGENT: {agent-a-id}] ..."
    ↓
Agent B extracts and saves the parent ID
    ↓
Agent B does work
    ↓
Agent B calls: sendMessageToAgent(targetAgentId: "{agent-a-id}", message: "...")
    ↓
Agent A receives: "[MESSAGE FROM AGENT: {agent-b-id}] ..."
    ↓
Agent A processes and continues
```

## Required Steps When Spawned

1. **Extract parent ID** from `[SPAWNED BY AGENT: {id}]`
2. **Save it** - you'll need it to respond
3. **Do your work**
4. **Call `sendMessageToAgent`** with results
5. **Call `setAgentStatus("idle")`**

## Message Format

### When Spawning an Agent

```
spawnAgent(
  agentType: "implementation",
  name: "Auth Implementation",
  initialPrompt: """
## Task
[Clear description of what to do]

## Context
[Relevant background]

## Key Files
- `path/file.dart:45` - Why relevant

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Response
Please message me back when complete with:
- What you implemented
- Files changed
- Verification results
"""
)
setAgentStatus("waitingForAgent")
```

### When Responding to Spawning Agent

```
sendMessageToAgent(
  targetAgentId: "{parent-id}",
  message: """
## Complete: [Task Name]

### Summary
What was accomplished.

### Changes
- Created: `file.dart` - purpose
- Modified: `other.dart:45` - what changed

### Verification
- ✅ Analysis clean
- ✅ Tests passing

### Notes
Any relevant observations.
"""
)
setAgentStatus("idle")
```

## Common Mistakes

### ❌ Forgetting to Send Message
```dart
// Agent writes "Implementation complete!" in response
// But never calls sendMessageToAgent
// Parent agent waits forever
```

### ✅ Correct Way
```dart
// Agent calls the tool
sendMessageToAgent(
  targetAgentId: "parent-id",
  message: "Implementation complete! ..."
)
setAgentStatus("idle")
```

### ❌ Forgetting to Set Status
```dart
sendMessageToAgent(...) // Good
// But forgot setAgentStatus("idle")
// Status shows "working" forever
```

### ✅ Correct Way
```dart
sendMessageToAgent(...)
setAgentStatus("idle") // Always do both
```

## Status Management

Always update your status appropriately:

| Situation | Status |
|-----------|--------|
| Actively working | `working` |
| Waiting for another agent | `waitingForAgent` |
| Waiting for user input | `waitingForUser` |
| Finished your work | `idle` |

## Message Checklist

Before finishing your turn:

- [ ] Did I extract the parent agent ID?
- [ ] Did the spawning message ask for a response? (Usually yes)
- [ ] Did I call `sendMessageToAgent` with my results?
- [ ] Did I call `setAgentStatus("idle")`?
- [ ] Is my message clear and complete?
