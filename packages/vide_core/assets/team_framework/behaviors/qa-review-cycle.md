---
name: qa-review-cycle
description: Mandatory QA review cycle - spawn qa-breaker, fix issues, re-review up to 2-3 rounds
---

# QA Review Cycle (MANDATORY)

After features are implemented (or after integration), you MUST run a QA review cycle. Do NOT skip this phase.

**YOU MUST ALWAYS spawn a qa-breaker to review the completed work.** This is non-negotiable. The qa-breaker acts as an adversarial reviewer who tries to break the implementation and find any issues.

**The QA Review Loop:**

```
Feature complete → QA Review → Issues found? → Implementer fixes → QA Review again → Repeat up to 2-3x
```

## Step 1: Spawn the QA reviewer

```dart
spawnAgent(
  agentType: "qa-breaker",
  name: "QA Review",
  initialPrompt: """
## Your Mission
Review and try to BREAK the implementation that was just completed.

## What Was Implemented
[Summary from the feature team(s)]

## Files Changed
[List of files changed]

## Success Criteria
[From requirements]

## Instructions
1. Read all changed files carefully
2. Run `dart analyze` to check for issues
3. Run `dart test` to verify tests pass
4. Try to find edge cases, bugs, security issues, missing error handling
5. Check that the implementation actually meets the requirements
6. Look for regressions in existing functionality

Report back with your findings. Be thorough and adversarial.
If everything looks solid, say so honestly. If there are issues, document them clearly.
"""
)
setAgentStatus("waitingForAgent")
// ⛔ STOP HERE. Wait for QA results.
```

## Step 2: If QA finds issues, spawn an implementer to fix them

```dart
// Only if QA reported issues
spawnAgent(
  agentType: "implementer",
  name: "QA Fix",
  initialPrompt: """
## Your Task
Fix the issues found by QA review.

## QA Report
[Paste the QA report here]

## Instructions
Fix all Critical and High issues. Address Medium issues if straightforward.
Run `dart analyze` and `dart test` after fixing.
Report back with what you fixed.
"""
)
setAgentStatus("waitingForAgent")
// ⛔ STOP HERE. Wait for fixes.
```

## Step 3: Spawn QA again to verify the fixes (Round 2)

After the implementer reports back, spawn the qa-breaker again to verify the fixes and look for any new issues. Repeat this cycle up to 2-3 times IF NEEDED.

**When to stop the cycle:**
- QA reports APPROVED with no critical/high issues → Done
- You've done 3 rounds and remaining issues are minor → Done, note the minor issues for the user
- QA keeps finding the same issues → Escalate to the user

**IMPORTANT:** Do NOT skip the QA phase even for "simple" changes. Simple changes break things too.
