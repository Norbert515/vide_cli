---
name: messaging
description: Core rules for agent-to-agent messaging
---

# Messaging Protocol

Agents communicate via `sendMessageToAgent`. This protocol ensures messages are clear, actionable, and properly received.

## IMPORTANT: Use vide-agent MCP, NOT Built-in Task Tool

**NEVER use the built-in `Task` tool to spawn agents or delegate work.**

Always use the `vide-agent` MCP tools instead:
- `spawnAgent` - Create a new agent in the network
- `sendMessageToAgent` - Communicate with other agents
- `setAgentStatus` - Update your status
- `terminateAgent` - Clean up agents when done

The built-in Task tool creates isolated subprocesses that:
- Cannot communicate with the agent network
- Cannot be monitored in the UI
- Cannot receive messages from other agents
- Are invisible to the orchestration system

**Always use `mcp__vide-agent__spawnAgent`, never `Task`.**

## The Golden Rule

**If someone asks you to report back, you MUST call `sendMessageToAgent`.**

Writing a summary in your response text is NOT the same as sending a message. The other agent will NOT receive it unless you invoke the tool.

## Message Lifecycle

```
Agent A spawns Agent B
    ↓
Agent B receives initial prompt (system delivers the spawn context)
    ↓
Agent B extracts and saves the parent ID
    ↓
Agent B does work
    ↓
Agent B calls: sendMessageToAgent(targetAgentId: "{agent-a-id}", message: "...")
    ↓
The system delivers Agent B's response to Agent A (system-generated, not agent-generated)
    ↓
Agent A processes and continues
```

⚠️ **CRITICAL: System-Generated Message Delivery.** When a sub-agent sends you a message, the **system** delivers it to you in a special format. You will NEVER generate this delivery text yourself. If you find yourself writing `[MESSAGE FROM AGENT` in your output, you are hallucinating a response that hasn't arrived yet — **STOP immediately.**

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
  role: "implementer",
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

## CRITICAL: Wait After Spawning Agents

When you spawn a sub-agent, you MUST determine whether it is a **BLOCKING** or **NON-BLOCKING** spawn.

### BLOCKING Spawns (Information-Gathering)

When you spawn an agent because you **need information to proceed** (researcher, context-gatherer, or ANY agent whose response you need before you can continue), you **MUST**:

1. Call `setAgentStatus("waitingForAgent")`
2. **End your turn IMMEDIATELY** — say only a brief message like "Let me look into that."
3. **Do NOT generate your own answer** — you don't have the information yet
4. **Do NOT guess or hallucinate** answers
5. Wait for the system to deliver the sub-agent's response to you in the next turn

**This is the most common mistake agents make.** After spawning a researcher, agents often immediately generate a detailed answer as if they already know the result. **This is hallucination.** You do NOT have the information yet. STOP and WAIT.

**"End your turn" means STOP producing output entirely.** Do not use `sleep`, polling loops, or any other trick to keep your turn alive while waiting. The system will automatically wake you up when the sub-agent responds. Just set your status to `waitingForAgent`, say a brief message, and **stop**.

### NON-BLOCKING Spawns (Independent Work)

When you spawn an agent for independent work where you **don't need their response to continue** (e.g., spawning multiple implementers in parallel while you coordinate), you may continue working.

### Rule of Thumb

**If you would need the agent's response to formulate your next action, it's a BLOCKING spawn. End your turn and wait.**

## Common Mistakes

### ❌ Hallucinating Sub-Agent Response
```dart
// Agent spawns researcher to explore codebase
spawnAgent(agentType: "researcher", ...)
setAgentStatus("waitingForAgent")
// Then IMMEDIATELY generates a detailed answer about the codebase
// without waiting for the researcher's response!
```

### ✅ Correct Way
```dart
spawnAgent(agentType: "researcher", ...)
setAgentStatus("waitingForAgent")
// Say ONLY: "Let me look into that."
// END YOUR TURN. The system will deliver the sub-agent's response to you.
```

### ❌ Using Sleep/Polling to Wait for Agents
```dart
// Agent spawns two researchers, then tries to stay alive
spawnAgent(agentType: "researcher", ...)
spawnAgent(agentType: "researcher", ...)
setAgentStatus("waitingForAgent")
// WRONG: uses sleep to keep the turn alive
Bash("sleep 60 && echo check")
// The system wakes you up automatically. Just END YOUR TURN.
```

### ✅ Correct Way
```dart
spawnAgent(agentType: "researcher", ...)
spawnAgent(agentType: "researcher", ...)
setAgentStatus("waitingForAgent")
// Say: "Looking into this." — then STOP. The system handles the rest.
```

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
