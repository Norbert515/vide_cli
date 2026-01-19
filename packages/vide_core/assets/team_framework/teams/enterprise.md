---
name: enterprise
description: Process-heavy, quality-focused. For production-critical and security-sensitive code.
icon: 🏛️

# Team composition - maps roles to agent personalities
composition:
  lead: cautious-lead
  planner: thorough-planner
  implementer: careful-implementer
  reviewer: thorough-reviewer
  tester: comprehensive-tester

# Process configuration
process:
  planning: thorough            # minimal | standard | thorough
  review: required              # skip | optional | required
  testing: comprehensive        # skip | smoke-only | recommended | comprehensive
  documentation: full           # skip | inline-only | full

# Communication style for this team
communication:
  verbosity: high               # low | medium | high
  handoff-detail: comprehensive # minimal | standard | comprehensive
  status-updates: continuous    # continuous | on-milestones | on-completion

# When to recommend this team
triggers:
  - "production"
  - "security"
  - "authentication"
  - "authorization"
  - "payment"
  - "billing"
  - "compliance"
  - "audit"
  - "public API"
  - "breaking change"
  - "migration"
  - "data"

# When NOT to use
anti-triggers:
  - "prototype"
  - "experiment"
  - "quick"
  - "hack"
---

# Enterprise Team

**Philosophy**: Measure twice, cut once. Quality and correctness over speed.

## How This Team Works

```
User Request
    ↓
Lead: Thorough assessment + requirement clarification
    ↓
Planner: Detailed implementation plan
    ↓
User: Reviews and approves plan
    ↓
Implementer: Careful, methodical implementation
    ↓
Reviewer: Comprehensive code review
    ↓
Implementer: Address all feedback
    ↓
Tester: Full test coverage verification
    ↓
Lead: Final sign-off
    ↓
Done
```

## This Team Is Great For

- Production systems
- Security-critical features
- Payment and financial code
- Data migrations
- Public API changes
- Compliance-required work
- Anything with audit requirements

## This Team Is NOT For

- Quick prototypes
- Exploratory work
- Internal tools
- Time-sensitive hotfixes

## Quality Gates

- All code must pass static analysis
- All tests must pass
- Code review approval required
- Security considerations documented
- Error handling comprehensive
- Edge cases covered
- Documentation complete

## Required Artifacts

- Implementation plan (before coding)
- Decision records (for architectural choices)
- Test coverage report
- Review approval
