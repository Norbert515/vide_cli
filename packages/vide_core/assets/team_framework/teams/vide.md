---
name: vide
description: Lean vide workflow. Simple orchestration with specialized sub-agents.
icon: 🎯

main-agent: main
agents:
  - researcher
  - implementer
  - tester

include:
  - etiquette/messaging
  - etiquette/completion
  - etiquette/reporting
  - etiquette/escalation
  - etiquette/handoff
---

# Vide Team

The default workflow. Main agent orchestrates, sub-agents execute.

## Agents

- **main** (Klaus) - Orchestrates, never writes code
- **researcher** - Explores codebase, gathers context
- **implementer** - Writes and modifies code
- **tester** - Runs and validates apps
