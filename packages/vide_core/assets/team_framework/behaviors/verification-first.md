---
name: verification-first
description: Establish verification approach BEFORE implementation begins
---

# Verification-First Protocol

Before any implementation begins, the team must know HOW the work will be verified. Verification is not an afterthought — it shapes the implementation.

## The Principle

**If you don't know how you'll prove it works, you're not ready to build it.**

## For Bug Fixes: Reproduce First

Before fixing a bug, you MUST reproduce it:

1. **Understand the reported behavior** — What exactly goes wrong?
2. **Find a reproduction path** — Write a failing test, run the app, or execute steps that demonstrate the bug
3. **Confirm the bug exists** — See it fail with your own eyes
4. **Then fix it** — Now you have a built-in verification: the reproduction should pass after your fix

**Why this matters:** A fix without reproduction proof is a guess. You might fix a symptom, not the cause. The reproduction becomes your regression test.

**Exception:** The user may explicitly say "skip reproduction" or "just fix it." Honor that request, but note in your report that reproduction was skipped.

## For New Features: Discover Verification Tools First

Before implementing a feature, discover what verification tools are available:

1. **Check for existing test suites** — `dart test`, test directories, CI scripts
2. **Check for linting/analysis** — `dart analyze`, custom lint rules
3. **Check for runtime testing tools** — Flutter runtime MCP (`flutterStart`, `flutterScreenshot`, `flutterGetElements`), TUI runtime MCP (`tuiStart`, `tuiGetScreen`, `tuiSendKey`)
4. **Check for project-specific scripts** — Build scripts, integration tests, E2E test harnesses, `justfile` commands
5. **Check for available MCP servers** — What testing MCPs are available to QA agents?

Then produce a **Verification Plan** — a short section that answers:
- What tools/commands will verify this works?
- What does "passing" look like for each success criterion?
- What can be automated vs. what needs manual verification?

## Verification Plan Format

```markdown
### Verification Plan

**Tools available:**
- `dart analyze` — Static analysis
- `dart test` — Unit/integration tests in test/
- [flutter-runtime MCP] — Can run and interact with the app
- [other project-specific tools discovered]

**How each success criterion will be verified:**
- [ ] [Criterion] → [How: test name, command, manual check, etc.]
- [ ] [Criterion] → [How]

**Reproduction (bug fixes only):**
- [ ] Bug reproduced via: [test/script/manual steps]
- [ ] After fix, reproduction passes
```

## Lightweight, Not Bureaucratic

The verification plan should be:
- **2-8 lines** for simple tasks (just list the commands/tests)
- **A short section** for complex tasks (map criteria to tools)
- **Never skipped** — even "run dart analyze and dart test" counts as a plan

A one-line verification plan is fine: "Verify via `dart test test/auth_test.dart` and `dart analyze`." The point is that it exists BEFORE implementation starts.
