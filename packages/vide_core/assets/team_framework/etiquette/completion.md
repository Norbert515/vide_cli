---
name: completion
description: How to complete work and report back to parent agent
---

# Completion Protocol

When you finish your work, you MUST follow this protocol. Your work is NOT complete until you do.

## Required Steps

1. **Verify your work** - Run analysis, tests, or whatever validation applies
2. **Call `sendMessageToAgent`** with your results to the parent agent
3. **Set your status**:
   - `setAgentStatus("idle")` — one-shot agents (you're done permanently)
   - `setAgentStatus("waitingForAgent")` — long-running agents (reporting back but staying alive for more work)

## One-Shot Completion

For agents that finish and are done:

```
sendMessageToAgent(
  targetAgentId: "{parent-id}",
  message: """
## Complete: [Task Name]

### Summary
[What was accomplished]

### Changes
- Created/Modified: `path/file.dart` - [purpose]

### Verification
- ✅ Analysis: Clean
- ✅ Tests: Passing

### Notes
[Anything the parent should know]
"""
)
setAgentStatus("idle")
```

## Long-Running Completion

For agents that report results but stay alive (testers, coordinators):

```
sendMessageToAgent(
  targetAgentId: "{parent-id}",
  message: "[Results summary]"
)
setAgentStatus("waitingForAgent")
```

Only call `setAgentStatus("idle")` when you're told your work is fully complete.

## Critical Reminder

**YOUR WORK IS NOT COMPLETE UNTIL YOU CALL `sendMessageToAgent`.**

Writing a summary in your response text is NOT the same as sending a message. The parent agent will NOT receive it unless you call the tool.
