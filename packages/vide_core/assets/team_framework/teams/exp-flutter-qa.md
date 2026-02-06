---
name: exp-flutter-qa
description: Parallel Flutter testing team. Spawns batches of isolated test runners for comprehensive app testing.
icon: 🧪

main-agent: test-coordinator
agents:
  - test-runner

include:
  - etiquette/messaging
  - etiquette/completion
  - etiquette/brief-reporting
  - etiquette/escalation
  - etiquette/handoff
---

# Exp. Flutter QA Team

Parallel Flutter testing team optimized for comprehensive app coverage through batched test execution.

## Philosophy

**Test fast, report brief.** Spawn multiple isolated test runners in parallel (1-5 at a time), aggregate results, move on.

## Agents

- **test-coordinator** (Patrol Lead) - Orchestrates test batches, aggregates results, never runs apps
- **test-runner** (Scout) - Single-purpose tester, runs one test scope, reports PASS/FAIL, terminates

## When to Use

Use this team when:
- Testing a Flutter app comprehensively
- Need to cover multiple screens/flows quickly
- Want parallel test execution
- Care about aggregate pass/fail, not detailed narration

## How It Works

1. **Coordinator assesses scope** - What areas need testing?
2. **Spawns batch of runners** - 1-5 parallel test agents
3. **Runners execute independently** - Each tests one area
4. **Runners report back** - Brief PASS/FAIL + errors
5. **Coordinator aggregates** - Collects all results
6. **Next batch or done** - Repeat until coverage complete

## Example Flow

```
User: Test my Flutter app thoroughly

Coordinator:
  → Spawns: Auth Runner, Nav Runner, Forms Runner (batch 1)
  ← Auth: ✅ PASS
  ← Nav: ❌ FAIL: Back button broken
  ← Forms: ✅ PASS

  → Spawns: Settings Runner, Profile Runner (batch 2)
  ← Settings: ✅ PASS
  ← Profile: ✅ PASS

Report to user:
  5/6 PASS, 1 FAIL (Navigation: back button)
```

## Communication Style

- **Coordinator → Runner**: Minimal handoff (what to test, how to report)
- **Runner → Coordinator**: PASS/FAIL + error details only
- **Coordinator → User**: Aggregate summary

## Comparison with Other Teams

| Aspect | Exp. Flutter QA | Flutter | Enterprise |
|--------|----------------|---------|------------|
| Testing style | Parallel batches | Single tester | Thorough QA |
| Communication | Minimal | Standard | Comprehensive |
| Speed | Fast | Medium | Slow |
| Coverage | Broad | Targeted | Deep |
