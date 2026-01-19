---
name: balanced
description: A well-rounded team balancing speed and quality. Good default for most tasks.
icon: ⚖️

# Team composition - maps roles to agent personalities
composition:
  lead: pragmatic-lead
  implementer: solid-implementer
  reviewer: pragmatic-reviewer  # Optional, for non-trivial changes
  tester: quick-tester          # Optional

# Process configuration
process:
  planning: standard            # minimal | standard | thorough
  review: optional              # skip | optional | required
  testing: recommended          # skip | smoke-only | recommended | comprehensive
  documentation: inline-only    # skip | inline-only | full

# Communication style for this team
communication:
  verbosity: medium             # low | medium | high
  handoff-detail: standard      # minimal | standard | comprehensive
  status-updates: on-milestones # continuous | on-milestones | on-completion

# When to recommend this team
triggers:
  - "add feature"
  - "implement"
  - "build"
  - "create"

# When NOT to use
anti-triggers:
  - "quick fix"
  - "hotfix"
  - "security"
  - "payment"
---

# Balanced Team

**Philosophy**: Ship quality code at a sustainable pace. Not the fastest, not the slowest—just right.

## How This Team Works

```
User Request
    ↓
Lead: Assess complexity and clarify requirements
    ↓
[If complex] Researcher: Gather context
    ↓
Implementer: Build the solution
    ↓
[If non-trivial] Reviewer: Quick review
    ↓
[If UI changes] Tester: Verify it works
    ↓
Done
```

## This Team Is Great For

- Standard feature development
- Moderate complexity tasks
- When you want a reasonable balance of speed and quality
- Day-to-day development work

## This Team Is NOT For

- Emergency hotfixes (use startup team)
- Security-critical code (use enterprise team)
- Pure research/exploration (use research team)

## Quality Gates

- Code should compile and pass linting
- Tests should pass (if they exist)
- Review recommended for changes touching multiple files
