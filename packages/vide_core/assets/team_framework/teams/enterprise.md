---
name: enterprise
description: Process-heavy, quality-focused. For production-critical code.
icon: 🏛️

main-agent: main
agents:
  - researcher
  - implementer
  - tester

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
  - "security"
  - "payment"
  - "compliance"
  - "migration"

anti-triggers:
  - "prototype"
  - "quick"
---

# Enterprise Team

Process-heavy workflow for production-critical code.

## Agents

Same agents as vide, but with more ceremony:

- **main** (Klaus) - Extra cautious, thorough assessment
- **researcher** - Deep research before any implementation
- **implementer** - Methodical, comprehensive error handling
- **tester** - Full coverage verification

## Workflow

1. Thorough requirements gathering
2. Detailed planning phase
3. Careful implementation
4. Comprehensive testing
5. Documentation

## Quality Gates

- All code passes static analysis
- All tests pass
- Error handling comprehensive
- Edge cases covered
