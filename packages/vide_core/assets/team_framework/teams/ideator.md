---
name: ideator
description: Creative brainstorming team that explores multiple directions in parallel. Always spawns divergent thinkers.
icon: 💡

# Team composition - maps roles to agent personalities
composition:
  lead: divergent-lead
  researcher: null                # Replaced by specialized thinkers
  thinker-creative: creative-explorer
  thinker-practical: practical-analyst
  thinker-critical: devils-advocate
  implementer: null               # This team ideates, not implements
  reviewer: null                  # No review during ideation
  tester: null                    # No testing during ideation

# Process configuration
process:
  planning: skip                  # Ideas first, planning later
  review: skip                    # No review during brainstorming
  testing: skip                   # No testing during ideation
  documentation: findings-only    # Capture the ideas

# Communication style for this team
communication:
  verbosity: high                 # Share all ideas
  handoff-detail: comprehensive   # Rich context for synthesis
  status-updates: continuous      # Real-time idea flow

# When to recommend this team
triggers:
  - "brainstorm"
  - "ideas"
  - "creative"
  - "think of"
  - "come up with"
  - "possibilities"
  - "alternatives"
  - "different ways"
  - "how might we"
  - "what if"
  - "explore options"
  - "blue sky"
  - "divergent"

# When NOT to use
anti-triggers:
  - "implement"
  - "build"
  - "fix"
  - "deploy"
  - "just do"
  - "quick"
  - "urgent"
---

# Ideator Team

**Philosophy**: Divergent thinking first, convergence later. Every request spawns multiple parallel thinkers exploring different angles.

## Core Mechanic

The divergent-lead **ALWAYS** spawns 2-4 parallel thinkers when receiving a request:

```
User Request
    ↓
Lead: Frame the question
    ↓
[PARALLEL SPAWN - ALWAYS]
    ├── Creative Explorer: Wild, unconventional ideas
    ├── Practical Analyst: Feasible, grounded approaches
    └── Devil's Advocate: Challenges, risks, alternatives
    ↓
[Thinkers work independently]
    ↓
Lead: Synthesize divergent perspectives
    ↓
Present unified ideation report
```

## This Team Is Great For

- Generating multiple solution approaches
- Breaking out of conventional thinking
- Exploring problem space before committing
- "How might we..." questions
- Early-stage product/feature ideation
- Challenging assumptions
- Finding creative alternatives

## This Team Is NOT For

- Clear implementation tasks
- Bug fixes
- Anything with time pressure
- Tasks with obvious solutions
- Production code changes

## Outputs

This team produces **ideas and perspectives**, not code:

- Multiple divergent approaches
- Creative alternatives
- Risk analysis and challenges
- Synthesis of different viewpoints
- Recommendations with rationale

## Success Criteria

- Multiple distinct approaches explored
- Unconventional ideas surfaced
- Practical constraints considered
- Challenges and risks identified
- User has rich options to consider
