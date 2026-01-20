---
name: enterprise
description: Team-oriented workflow with natural team formation. Features owned end-to-end by feature teams. Parallel work, iterative quality. For long-running, production-critical work.
icon: 🏛️

main-agent: enterprise-lead
agents:
  - feature-lead
  - requirements-analyst
  - solution-architect
  - implementer
  - researcher
  - qa-breaker

process:
  planning: thorough
  review: required
  testing: comprehensive
  documentation: full

communication:
  verbosity: high
  handoff-detail: comprehensive
  status-updates: continuous

triggers:
  - "production"
  - "enterprise"
  - "security"
  - "payment"
  - "compliance"
  - "migration"
  - "critical"
  - "thorough"
  - "rigorous"

anti-triggers:
  - "prototype"
  - "quick"
  - "hack"
  - "experiment"
---

# Enterprise Team

Team-oriented workflow where **natural team structures emerge** around features. Designed for long-running, production-critical work.

## Philosophy

**Teams, not tasks. Ownership, not handoffs.**

- Features are owned end-to-end by feature teams
- Teams iterate internally until quality is achieved
- Parallel work is the norm, not the exception
- The enterprise-lead coordinates between teams, not within them

## How It Works

```
Enterprise Lead (Orchestrator)
│
├── Requirements Analyst → understands full scope
├── Solution Architect → breaks into features, designs teams
│
├── Feature Team A ─────────┐
│   ├── Feature Lead        │
│   ├── Implementer(s)      │ parallel
│   └── QA Breaker          │
│                           │
├── Feature Team B ─────────┤
│   ├── Feature Lead        │
│   ├── Implementer(s)      │
│   └── QA Breaker          │
│                           ┘
├── Integration Team (when features complete)
│   ├── Feature Lead
│   ├── Implementer
│   └── QA Breaker
│
└── Final Report to User
```

## Agents

### Orchestration
- **enterprise-lead** - Coordinates teams. Breaks work into features. Never does implementation work.

### Team Leadership
- **feature-lead** - Owns a feature end-to-end. Spawns their own team (implementers, qa-breaker). Iterates until quality achieved.

### Analysis (before team formation)
- **requirements-analyst** - Deep problem understanding. Identifies features and dependencies.
- **solution-architect** - High-level design. Recommends team structure.

### Implementation (spawned by feature leads)
- **implementer** - Writes code. Follows the design.
- **researcher** - Gathers context when needed.
- **qa-breaker** - Adversarial testing. Tries to break things.

## Team Patterns

### Single Feature
```
Enterprise Lead
└── Feature Lead → owns feature
    ├── Implementer
    └── QA Breaker
```

### Multiple Independent Features (Parallel)
```
Enterprise Lead
├── Feature Lead A ──┐
├── Feature Lead B ──┤ parallel
├── Feature Lead C ──┘
└── Integration Lead
```

### Phased Features (Dependencies)
```
Enterprise Lead
├── Phase 1: Feature A, Feature B (parallel)
├── Phase 1 Integration
├── Phase 2: Feature C, Feature D (depend on Phase 1)
└── Final Integration
```

## Key Differentiators

### Feature Ownership

Each feature has a **Feature Lead** who:
- Can read code to understand context
- Spawns their own implementers and qa-breaker
- Iterates internally until quality achieved
- Reports completion to enterprise-lead

The enterprise-lead doesn't micromanage - they delegate complete ownership.

### Natural Team Formation

Teams form organically based on the work:
- Small feature → 1 implementer + QA
- Medium feature → 2-3 implementers (parallel) + QA
- Complex feature → sub-teams with coordination

Feature leads decide their team size based on the work.

### Parallel Execution

Independent features run in parallel:
- Auth Team + Rate Limiting Team + Logging Team
- All working simultaneously
- Integration when features complete

### Iterative Quality

Each team owns their quality:
- Feature Lead coordinates implement → QA → fix → QA loops
- Teams don't report "done" until QA approves
- Enterprise-lead sees completion, not iteration details

## Workflow

1. **Understand** - Requirements analyst explores full scope
2. **Design** - Solution architect breaks into features, maps dependencies
3. **Team Formation** - Enterprise-lead spawns feature leads for each feature
4. **Parallel Execution** - Feature teams work simultaneously
5. **Integration** - Integration team connects completed features
6. **Completion** - Enterprise-lead synthesizes all team reports

## When to Use Enterprise

- Production deployments with multiple components
- Security-sensitive features
- Payment/financial systems
- Large features that benefit from team ownership
- Long-running autonomous work (hours, not minutes)
- When you want parallel progress on multiple fronts

## When NOT to Use Enterprise

- Quick prototypes
- Single-file changes
- Experiments
- Time-critical hotfixes

## Scaling

The enterprise structure scales naturally:
- More features = more feature teams (parallel)
- Larger features = feature leads spawn more agents
- Complex integration = dedicated integration team

Teams can work for extended periods. Progress updates flow up to enterprise-lead, who synthesizes for the user.
