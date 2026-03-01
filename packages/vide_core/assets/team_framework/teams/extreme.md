---
name: extreme
description: Maximum rigor through dual-harness parallel analysis, direct agent debates, dedicated verification strategy, and comprehensive dual-model review. For when correctness is paramount.
icon: ⚡

main-agent: extreme-lead
agents:
  - feature-lead
  - requirements-analyst
  - solution-architect
  - implementer
  - researcher
  - qa-breaker
  - code-reviewer
  - verification-strategist

disallowedTools: Task

include:
  - etiquette/messaging
  - etiquette/completion
  - etiquette/reporting
  - etiquette/escalation
  - etiquette/handoff
  - behaviors/verification-first
  - behaviors/dual-harness-debate

lifecycle-triggers:
  onTaskComplete:
    enabled: true
    spawn: code-reviewer

process:
  planning: thorough
  review: required
  testing: comprehensive
  documentation: inline-only

communication:
  verbosity: high
  handoff-detail: comprehensive
  status-updates: continuous
---

# Extreme Team

Maximum rigor workflow where **every analysis is dual-model debated** and verification is established before any work begins. Designed for high-stakes, correctness-critical work.

## Philosophy

**Trust nothing. Verify everything. Let models argue.**

- Every analysis phase runs on TWO different AI backends (Claude + Codex) in parallel
- Agents debate each other directly — 2-3 rounds of adversarial critique
- A dedicated verification strategist establishes the testing loop before any implementation
- Code review is dual-model: both backends review independently, then debate findings
- Standard QA cycle runs AFTER dual-model review

## How It Works

```
Extreme Lead (Orchestrator)
│
├── Phase 0: Verification Strategy
│   └── Verification Strategist
│       → Discovers tools, builds test harnesses, maps success criteria
│
├── Phase 1: Dual-Harness Requirements (PARALLEL + DEBATE)
│   ├── Requirements Analyst (Claude Code)
│   └── Requirements Analyst (Codex)
│   └── → 2-3 rounds of direct debate
│   └── → Lead synthesizes final requirements
│
├── Phase 2: Dual-Harness Architecture (PARALLEL + DEBATE)
│   ├── Solution Architect (Claude Code)
│   └── Solution Architect (Codex)
│   └── → 2-3 rounds of direct debate
│   └── → Lead synthesizes architecture
│
├── Phase 3: Implementation
│   └── Feature Lead(s) → standard feature team pattern
│       ├── Implementer(s)
│       └── Internal QA
│
├── Phase 4: Dual-Harness Review (PARALLEL + DEBATE)
│   ├── Code Reviewer (Claude Code)
│   └── Code Reviewer (Codex)
│   └── → Debate findings, lead synthesizes
│
├── Phase 5: QA Review (MANDATORY)
│   └── QA Breaker → uses verification strategy from Phase 0
│
└── Final Report to User
```

## Agents

### Orchestration
- **extreme-lead** - Coordinates teams, moderates debates. Never does implementation work.

### Verification
- **verification-strategist** - Discovers and builds verification infrastructure before any implementation begins.

### Team Leadership
- **feature-lead** - Owns a feature end-to-end. Spawns implementers and qa-breaker.

### Analysis (dual-harness debated)
- **requirements-analyst** - Deep problem understanding. Spawned in pairs on different harnesses.
- **solution-architect** - Architecture design. Spawned in pairs on different harnesses.

### Implementation (spawned by feature leads)
- **implementer** - Writes code.
- **researcher** - Gathers context when needed.

### Review (dual-harness debated)
- **code-reviewer** - Code review. Spawned in pairs on different harnesses.
- **qa-breaker** - Adversarial testing using the verification strategy.

## Debate Pattern

Every analysis/review phase follows this pattern:

1. **Parallel work** — Two agents (different harnesses) work independently
2. **Cross-pollination** — Lead sends each agent the other's findings
3. **Direct debate** — Agents message each other with critiques (2-3 rounds)
4. **Synthesis** — Lead takes the best from both perspectives

The debate produces higher-quality analysis than either model alone because:
- Different models spot different blind spots
- Adversarial critique forces clearer reasoning
- Cross-pollination catches missed details
- Synthesis combines the best of both approaches

## Key Differentiators from Enterprise

| Aspect | Enterprise | Extreme |
|--------|-----------|---------|
| Verification | Inline with analysis | Dedicated strategist, Phase 0 |
| Requirements | Single analyst | Dual-model + debate |
| Architecture | Single architect | Dual-model + debate |
| Implementation | Same | Same (feature teams) |
| Code Review | Single reviewer | Dual-model + debate |
| QA | Standard | Standard (on top of dual review) |
| Total Rigor | High | Maximum |
| Overhead | Moderate | ~1.5x enterprise |

## When to Use Extreme

- Security-critical features (auth, encryption, permissions)
- Financial/payment logic
- Data migration or transformation
- Public API design
- Architecture decisions with long-term implications
- Any work where "getting it wrong" has high cost

## When NOT to Use Extreme

- Rapid prototyping
- Simple bug fixes
- UI polish / cosmetic changes
- Tasks where speed matters more than correctness
- Anything that doesn't justify 1.5x overhead
