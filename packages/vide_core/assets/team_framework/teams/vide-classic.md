---
name: vide-classic
description: The original Vide multi-agent workflow. Cautious orchestration with specialized sub-agents for research, planning, implementation, and Flutter testing.
icon: 🎯

# Team composition - maps roles to vide agent personalities
composition:
  lead: vide-main-orchestrator
  researcher: vide-context-researcher
  planner: vide-planner
  implementer: vide-implementer
  tester: vide-flutter-tester

# Process configuration - matches current vide behavior
process:
  planning: adaptive            # Planning agent used for complex tasks (>3 files)
  review: skip                  # No dedicated reviewer in classic vide
  testing: recommended          # Flutter tester used for UI changes
  documentation: inline-only    # No formal documentation phase

# Communication style - high detail handoffs
communication:
  verbosity: medium
  handoff-detail: comprehensive # Full context in agent spawning
  status-updates: continuous    # Agents report back promptly

# When to recommend this team (default for vide)
triggers:
  - default                     # This is the default vide team

# When NOT to use
anti-triggers: []               # Always available
---

# Vide Classic Team

**Philosophy**: Cautious orchestration with aggressive delegation. The main agent never writes code - it assesses, clarifies, and delegates to specialized sub-agents.

## How This Team Works

```
User Request
    ↓
Main Orchestrator: Assess complexity
    ├─ Bulletproof clear? → Spawn Implementer directly
    └─ Needs research? → Continue below
    ↓
Spawn Context Researcher: Gather codebase context
    ↓
Main Orchestrator: Present findings, clarify with user
    ↓
[If complex] Spawn Planner: Create implementation plan
    ↓
User: Approve plan
    ↓
Spawn Implementer: Build the solution
    ↓
[If Flutter UI] Spawn Flutter Tester: Verify changes
    ↓
Main Orchestrator: Synthesize and report to user
```

## Core Principles

### 1. When In Doubt, Ask
The main orchestrator errs on the side of caution. Better to ask one clarifying question than implement the wrong solution.

### 2. Aggressive Delegation
- **Context Researcher**: For ALL non-trivial exploration (don't grep yourself)
- **Planner**: For complex tasks (>3 files, architectural decisions)
- **Implementer**: For ALL code changes (never write code in orchestrator)
- **Flutter Tester**: For ALL Flutter app testing (orchestrator lacks Flutter Runtime)

### 3. Async Message Passing
Agents communicate via `sendMessageToAgent`. The orchestrator spawns agents and continues working - agents message back when done.

### 4. Iterative Collaboration
- Flutter Tester can spawn Implementation agents to fix issues it finds
- Multiple research rounds are normal (research → ask → research more)
- Agents stay alive for follow-up work when appropriate

## Agent Capabilities Summary

| Agent | Can Do | Cannot Do |
|-------|--------|-----------|
| Main Orchestrator | Read, Grep, Glob (minimal), Spawn agents | Write code, Run Flutter apps |
| Context Researcher | Read, Grep, Glob, WebSearch, WebFetch | Write code |
| Planner | Read, Grep, Glob | Write code, Execute |
| Implementer | Read, Write, Edit, Bash, Spawn tester | - |
| Flutter Tester | Flutter Runtime, Spawn implementer | - |

## This Team Is Great For

- General development tasks
- Flutter/Dart projects
- Tasks requiring careful requirements gathering
- Complex features needing planning
- Iterative test-fix cycles

## Quality Gates

- Main orchestrator clarifies before complex implementation
- Implementation agent runs `dart analyze` before completion
- Flutter tester verifies UI changes with screenshots
- All agents report back with verification results
