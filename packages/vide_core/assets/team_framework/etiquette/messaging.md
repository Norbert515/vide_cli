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

## NEVER Hallucinate Sub-Agent Responses

**This is the #1 rule in this entire protocol.**

After you spawn a sub-agent, the sub-agent works **asynchronously**. You do NOT know what they will find. You do NOT have their results. The system will deliver their response to you in a **future turn** — you cannot predict, summarize, or fabricate it.

**What hallucination looks like** — if you catch yourself doing ANY of these after spawning an agent, STOP IMMEDIATELY:

- Writing a detailed analysis of the codebase right after spawning a researcher (you haven't received their findings yet)
- Describing what files exist or what patterns are used right after asking an agent to explore (you don't know yet)
- Writing `[MESSAGE FROM AGENT` in your output (this is a system-generated delivery format — you never produce it)
- Continuing to plan the next phase right after spawning an information-gathering agent (you're supposed to wait for the info first)
- Generating any substantive content about the task after spawning a blocking agent (you should be saying only a brief message like "Looking into it." and stopping)

**Why this matters:** Hallucinated responses contain fabricated information. The user sees confident-sounding but wrong answers. The actual sub-agent's real findings are ignored. This is the single most damaging failure mode in the agent system.

## CRITICAL: Wait After Spawning Agents

When you spawn a sub-agent, you MUST determine whether it is a **BLOCKING** or **NON-BLOCKING** spawn.

### BLOCKING Spawns

When you spawn an agent because you **need information to proceed** (researcher, requirements-analyst, solution-architect, or ANY agent whose response you need before continuing), you **MUST**:

1. Call `setAgentStatus("waitingForAgent")`
2. **End your turn IMMEDIATELY** — say only a brief message like "Let me look into that."
3. **Do NOT generate your own answer** — you don't have the information yet
4. **Do NOT guess or hallucinate** answers
5. **STOP producing output.** The system will wake you up when the sub-agent responds.

**"End your turn" means STOP producing output entirely.** Do not use `sleep`, polling loops, or any other trick to keep your turn alive while waiting. The system will automatically wake you up when the sub-agent responds.

### NON-BLOCKING Spawns

When you spawn an agent for independent work where you **don't need their response to continue** (e.g., spawning multiple implementers in parallel while you coordinate), you may continue working.

### Rule of Thumb

**If you would need the agent's response to formulate your next action, it's a BLOCKING spawn. End your turn and wait.**

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

⚠️ **System-Generated Message Delivery.** When a sub-agent sends you a message, the **system** delivers it to you in a special format. You will NEVER generate this delivery text yourself. If you find yourself writing `[MESSAGE FROM AGENT` in your output, you are hallucinating a response that hasn't arrived yet — **STOP immediately.**

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

## Common Mistakes

### ❌ Hallucinating Sub-Agent Response
```
// WRONG: Agent spawns researcher, then immediately writes a detailed answer
spawnAgent(agentType: "researcher", ...)
setAgentStatus("waitingForAgent")
// "Based on my analysis, the codebase uses X pattern and Y library..."
// ^^^ This is FABRICATED. The researcher hasn't reported back yet!
```

### ✅ Correct Way
```
spawnAgent(agentType: "researcher", ...)
setAgentStatus("waitingForAgent")
// Say ONLY: "Let me look into that."
// END YOUR TURN. The system will deliver the sub-agent's response to you.
```

### ❌ Forgetting to Send Message
```
// Agent writes "Implementation complete!" in response text
// But never calls sendMessageToAgent
// Parent agent waits forever — it only receives tool-delivered messages
```

### ✅ Correct Way
```
sendMessageToAgent(
  targetAgentId: "parent-id",
  message: "Implementation complete! ..."
)
setAgentStatus("idle")
```

### ❌ Forgetting to Set Status
```
sendMessageToAgent(...) // Good
// But forgot setAgentStatus("idle")
// Status shows "working" forever in the UI
```

### ✅ Correct Way
```
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
