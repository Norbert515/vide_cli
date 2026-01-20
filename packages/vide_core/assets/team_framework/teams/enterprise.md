---
name: enterprise
description: Rigorous process-driven workflow. Problem understanding, solution exploration, verification planning, implementation, adversarial QA. For long-running, production-critical work.
icon: 🏛️

main-agent: enterprise-lead
agents:
  - requirements-analyst
  - solution-architect
  - verification-planner
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

Rigorous, process-driven workflow designed for production-critical code and long-running autonomous work.

## Philosophy

**Process prevents problems. Haste creates them.**

- A bug in production costs 100x more than catching it early
- Misunderstood requirements waste entire development cycles
- Untested code is unfinished code
- Multiple solutions should be explored before committing

## The Enterprise Process

Every non-trivial task follows this mandatory flow:

```
PHASE 1: UNDERSTAND
    Requirements Analyst deeply explores the problem
    Ambiguities identified and clarified with user

PHASE 2: DESIGN
    Solution Architect explores multiple approaches
    Trade-offs analyzed objectively
    Best solution recommended with reasoning

PHASE 3: PLAN VERIFICATION
    Verification Planner designs test strategy
    Tooling gaps identified
    Build tooling BEFORE implementation if needed

PHASE 4: IMPLEMENT
    Implementer follows approved design
    Basic verification (analysis, unit tests)

PHASE 5: ADVERSARIAL QA
    QA Breaker tries to BREAK the implementation
    Issues found → Fix → Re-test
    Loop until QA APPROVED

PHASE 6: COMPLETE
    Full report to user
```

## Agents

### Leadership
- **enterprise-lead** - Pure orchestrator. Delegates ALL work. Follows process strictly.

### Phase 1: Understanding
- **requirements-analyst** - Deep requirements analysis. Makes problem crystal clear before any solution work.

### Phase 2: Design
- **solution-architect** - Explores multiple solutions. Never implements, only designs and recommends.
- **verification-planner** - Plans how to verify BEFORE implementation. Identifies tooling needs.

### Phase 3-4: Implementation
- **implementer** - Writes code following approved design.
- **researcher** - Gathers additional context if needed.

### Phase 5: Verification
- **qa-breaker** - Adversarial tester. Mission is to BREAK the implementation. Iterates until bulletproof.

## Key Differentiators

### Main Agent Does NO Work

The enterprise-lead has almost no tools. It cannot:
- Read code
- Write code
- Run applications
- Explore the codebase

It can ONLY:
- Spawn agents
- Send messages
- Track tasks
- Communicate with users

This forces proper delegation and prevents shortcuts.

### Multiple Solutions Explored

Before implementing, the solution-architect MUST:
- Generate 2-3+ viable approaches
- Analyze trade-offs objectively
- Recommend with clear reasoning

The "obvious" solution is often not the best.

### Verification Planned FIRST

Before coding starts, we know:
- What tests prove it works
- What edge cases to check
- What tooling is needed
- How QA will verify it

If we can't verify it, we can't trust it.

### Adversarial QA

The qa-breaker's job is to BREAK things:
- Boundary testing
- State manipulation
- Timing attacks
- Input fuzzing
- Error path testing

Implementation is not "done" until QA can't break it.

### Iteration Until Quality

The QA/Fix loop continues until:
- All verification checks pass
- All edge cases handled
- No security concerns
- QA formally approves

No arbitrary iteration limits. Quality is the only exit criteria.

## When to Use Enterprise

- Production deployments
- Security-sensitive features
- Payment/financial systems
- Compliance requirements
- Data migrations
- Features that "must not fail"
- Long-running autonomous tasks
- When you want thorough work, not fast work

## When NOT to Use Enterprise

- Quick prototypes
- Experiments
- Throwaway code
- Learning/exploration
- Time-critical hotfixes (use vide team with focused scope instead)

## Quality Gates

At each phase transition:

- **After Requirements**: Problem is crystal clear, success criteria defined
- **After Design**: Best solution selected with reasoning, trade-offs documented
- **After Verification Plan**: Test strategy complete, tooling identified
- **After Implementation**: Analysis clean, unit tests pass
- **After QA**: All checks pass, QA formally approves

No phase proceeds without prior phase completing successfully.
