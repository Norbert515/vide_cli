---
name: handoff
description: How to pass work between agents
---

# Handoff Protocol

When passing work to another agent, use structured handoffs to ensure nothing is lost in translation.

## Core Principle

**Treat handoffs like API contracts**: structured, versioned, and validated.

## Required Elements

Every handoff MUST include:

### 1. Context Summary
What the receiving agent needs to know:

```markdown
## Context
- **Task**: [Original user request]
- **Progress**: [What's been done so far]
- **Key files**: [Relevant files with line numbers]
- **Decisions made**: [Any choices already locked in]
```

### 2. Specific Request
Exactly what you need from the receiving agent:

```markdown
## Request
[Clear, actionable description of what to do]

**Scope**: [What's in scope / out of scope]
```

### 3. Acceptance Criteria
How we know the work is done:

```markdown
## Done When
- [ ] Specific measurable outcome 1
- [ ] Specific measurable outcome 2
- [ ] Verification passes (analysis/tests)
```

### 4. Response Expectation
How and when to report back:

```markdown
## Response
Please message me back with:
- Summary of what was done
- Files created/modified
- Any issues or concerns
- Verification results
```

## Handoff Template

```markdown
## Handoff: [Brief Title]

### Context
- **Task**: [What the user asked for]
- **Progress**: [What's done]
- **Key files**:
  - `path/file.dart:45` - [Why relevant]
  - `path/other.dart:100` - [Why relevant]
- **Decisions**: [Choices already made]

### Request
[What you need the receiving agent to do]

### Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Analysis clean / Tests pass

### Context Files
[List any files the agent should read first]

### Response Expected
Message me back when complete with:
- What was implemented
- Files changed
- Verification results
```

## Good vs Bad Handoffs

### ❌ Bad Handoff
```
"Fix the auth bug and let me know when done"
```
- No context
- No specific files
- No acceptance criteria
- Vague scope

### ✅ Good Handoff
```markdown
## Handoff: Fix Auth Token Expiry Bug

### Context
- **Task**: User reported login sessions expiring unexpectedly
- **Progress**: Investigated and found the issue
- **Key files**:
  - `lib/services/auth_service.dart:89` - Token refresh logic
  - `lib/models/session.dart:45` - Session model
- **Decisions**: Using existing refresh token pattern

### Request
Fix the token refresh logic in auth_service.dart. The issue is that
`refreshToken()` doesn't update the expiry timestamp after refresh.

### Acceptance Criteria
- [ ] Token expiry updates after refresh
- [ ] Existing tests still pass
- [ ] No analysis errors

### Response Expected
Message me back with the fix summary and test results.
```

## Handoff Checklist

Before sending a handoff, verify:

- [ ] Context is complete (receiving agent can work independently)
- [ ] Request is specific and actionable
- [ ] Acceptance criteria are measurable
- [ ] Response expectation is clear
- [ ] Relevant files are listed with line numbers
