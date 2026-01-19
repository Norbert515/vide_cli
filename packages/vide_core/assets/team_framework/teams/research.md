---
name: research
description: Exploratory team for ambiguous problems. Iterates until clarity emerges.
icon: 🔬

# Team composition - maps roles to agent personalities
composition:
  lead: curious-lead
  researcher: deep-researcher
  prototyper: rapid-prototyper
  reviewer: null                # No formal review during exploration
  tester: null                  # Testing comes later

# Process configuration
process:
  planning: adaptive            # minimal | standard | thorough | adaptive
  review: skip                  # skip | optional | required
  testing: skip                 # skip | smoke-only | recommended | comprehensive
  documentation: findings-only  # skip | inline-only | full | findings-only

# Communication style for this team
communication:
  verbosity: high               # low | medium | high (lots of findings to share)
  handoff-detail: comprehensive # minimal | standard | comprehensive
  status-updates: continuous    # continuous | on-milestones | on-completion

# When to recommend this team
triggers:
  - "research"
  - "investigate"
  - "explore"
  - "understand"
  - "figure out"
  - "how does"
  - "what's the best way"
  - "compare options"
  - "spike"
  - "proof of concept"
  - "POC"

# When NOT to use
anti-triggers:
  - "implement"
  - "build"
  - "ship"
  - "deploy"
  - "fix bug"
---

# Research Team

**Philosophy**: Explore first, understand deeply, then recommend. Clarity emerges through iteration.

## How This Team Works

```
User Request (ambiguous)
    ↓
Lead: Frame the research questions
    ↓
Researcher: Deep dive into codebase/docs/options
    ↓
Researcher: Document findings
    ↓
[If needed] Prototyper: Quick experiments to validate assumptions
    ↓
Lead: Synthesize findings into recommendations
    ↓
Present options to user
    ↓
[User decides direction]
    ↓
Hand off to appropriate team for implementation
```

## This Team Is Great For

- Understanding unfamiliar codebases
- Evaluating technology options
- Architecture exploration
- Complex debugging (root cause analysis)
- "How should we approach X?" questions
- Spikes and proof-of-concepts
- Learning new frameworks/libraries

## This Team Is NOT For

- Clear implementation tasks
- Bug fixes with known solutions
- Anything with a deadline
- Production deployments

## Outputs

This team produces **knowledge**, not code:

- Research findings documents
- Option comparisons (pros/cons)
- Architecture recommendations
- Prototype code (throwaway, for learning)
- Decision recommendations

## Success Criteria

- Questions are answered
- Options are clearly laid out
- Recommendations are actionable
- User has enough info to decide
