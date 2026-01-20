---
name: vide
description: Default vide workflow. Lean orchestration with specialized sub-agents.
icon: 🎯

main-agent: main
agents:
  - researcher
  - implementer
  - tester

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
  - default
---

# Vide Team

The default workflow. Main agent orchestrates, sub-agents execute.

## Agents

- **main** (Klaus) - Orchestrates, never writes code
- **researcher** - Explores codebase, gathers context
- **implementer** - Writes and modifies code
- **tester** - Runs and validates apps
