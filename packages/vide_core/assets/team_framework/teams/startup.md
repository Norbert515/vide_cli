---
name: startup
description: Move fast, ship often. Minimal process overhead for clear requirements and tight deadlines.
icon: 🚀

# Team composition - maps roles to agent personalities
composition:
  lead: pragmatic-lead
  implementer: speed-demon
  reviewer: null                # No reviewer - skip code review
  tester: smoke-tester          # Quick sanity checks only

# Process configuration
process:
  planning: minimal             # minimal | standard | thorough
  review: skip                  # skip | optional | required
  testing: smoke-only           # skip | smoke-only | recommended | comprehensive
  documentation: skip           # skip | inline-only | full

# Communication style for this team
communication:
  verbosity: low                # low | medium | high
  handoff-detail: minimal       # minimal | standard | comprehensive
  status-updates: on-completion # continuous | on-milestones | on-completion

# When to recommend this team
triggers:
  - "quick fix"
  - "hotfix"
  - "prototype"
  - "MVP"
  - "hack"
  - "just make it work"
  - "ASAP"
  - "urgent"

# When NOT to use
anti-triggers:
  - "production"
  - "security"
  - "payment"
  - "compliance"
  - "audit"
  - "public API"
---

# Startup Team

**Philosophy**: Ship it. Learn from users. Iterate. Perfect is the enemy of done.

## How This Team Works

```
User Request
    ↓
Lead: Quick assessment (30 sec max)
    ↓
Implementer: Build it fast
    ↓
[Optional] Tester: Quick smoke test
    ↓
Done
```

## This Team Is Great For

- Prototypes and MVPs
- Internal tools
- Exploratory features
- Tight deadlines
- Bug fixes with clear solutions
- "Just get it working" tasks

## This Team Is NOT For

- User-facing production code
- Security-sensitive features
- Payment/financial code
- Anything requiring audit trails
- Complex architectural changes

## Quality Gates

- Code must compile
- Basic functionality must work
- That's it. Ship it.

## Tradeoffs Accepted

- Technical debt may accumulate
- Error handling may be minimal
- Documentation will be sparse
- Edge cases may not be handled
