---
name: parallel
description: Git-aware dispatcher. Routes requests to agents on isolated worktrees. Parallel work with automatic merging.
icon: 🔀

main-agent: dispatcher
agents:
  - worker

process:
  planning: minimal
  review: skip
  testing: recommended
  documentation: skip

communication:
  verbosity: low
  handoff-detail: standard
  status-updates: on-completion

triggers:
  - "parallel"
  - "worktree"
  - "isolated"
  - "multiple features"
  - "branch"
---

# Parallel Team

Git-aware workflow where the main agent **only routes requests** to workers on isolated worktrees.

## Philosophy

**Route, don't execute. Isolate, then integrate.**

- Dispatcher never does implementation work
- Each task gets its own agent (potentially on its own worktree)
- Work happens in parallel, isolated branches
- Dispatcher handles merging when complete

## How It Works

```
User Request
    ↓
Dispatcher (main agent)
    ↓
Decision: New agent? Existing agent? Worktree needed?
    ↓
┌─────────────────────────────────────────────┐
│  Worktree A          Worktree B             │
│  (feature/auth)      (feature/rate-limit)   │
│       ↓                    ↓                │
│    Worker A            Worker B             │  parallel
│       ↓                    ↓                │
│   Complete             Complete             │
└─────────────────────────────────────────────┘
    ↓                        ↓
    └────────┬───────────────┘
             ↓
        Dispatcher merges both to main
             ↓
        Clean up worktrees
             ↓
        Report to user
```

## Agents

### Orchestration
- **dispatcher** - Routes requests. Creates worktrees. Manages merging. Never implements.

### Execution
- **worker** - General-purpose implementation agent. Does the actual work.

## Key Features

### Git Worktree Isolation

Each substantial task gets its own worktree:
- `../project-feature-auth` → branch `feature/auth`
- `../project-feature-rate-limit` → branch `feature/rate-limit`

Workers operate in complete isolation. No stepping on each other's toes.

### Automatic Merging

When a worker completes:
1. Dispatcher switches to main
2. Merges the feature branch
3. Removes the worktree
4. Cleans up

User doesn't manage git - it just happens.

### Smart Routing

Dispatcher decides per request:
- **New agent** - Unrelated to existing work
- **Existing agent** - Follow-up or related request
- **Worktree** - Multi-file changes, features, experiments
- **No worktree** - Quick fixes, single-file changes

## Workflow Example

```
User: "Add authentication and rate limiting"

Dispatcher:
  1. Creates worktree feature/auth → spawns Worker A
  2. Creates worktree feature/rate-limit → spawns Worker B
  3. Both work in parallel

Worker A completes → Dispatcher merges feature/auth
Worker B completes → Dispatcher merges feature/rate-limit

Dispatcher: "Both features complete and merged to main."
```

## When to Use Parallel

- Multiple independent features at once
- Work that benefits from git isolation
- When you want parallel progress
- Experimental changes that might be reverted
- Long-running tasks that shouldn't block each other

## When NOT to Use Parallel

- Single focused task (use vide team instead)
- Tightly coupled changes that must be coordinated
- When you need the rigor of enterprise process

## Comparison

| Aspect | Vide | Enterprise | Parallel |
|--------|------|------------|----------|
| Main agent does work | Yes (delegates some) | No | No |
| Worktree isolation | Optional | Optional | Default |
| Parallel execution | Possible | Common | Expected |
| Git management | Manual | Manual | Automatic |
| Process overhead | Low | High | Low |

## Scaling

The parallel team scales naturally:
- 5 features? 5 worktrees, 5 workers
- All work simultaneously
- Merge as they complete
- No coordination overhead
