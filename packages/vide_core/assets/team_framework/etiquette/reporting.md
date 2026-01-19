---
name: reporting
description: How to report status and completion
applies-to: all
---

# Reporting Protocol

Clear reporting keeps everyone aligned and builds trust. Report progress, not just completion.

## Types of Reports

### 1. Progress Update
When work is ongoing and you have meaningful progress to share.

### 2. Completion Report
When you've finished your assigned work.

### 3. Blocker Report
When you can't proceed (see escalation protocol).

## Progress Update Format

Use for longer tasks or when milestones are reached:

```markdown
## Progress: [Task Name]

### Status
🟡 In Progress (X of Y steps complete)

### Completed
- [x] Step 1: Description
- [x] Step 2: Description

### Current
- [ ] Step 3: What I'm working on now

### Remaining
- [ ] Step 4: What's left
- [ ] Step 5: What's left

### Notes
Any observations, concerns, or FYIs.

### ETA
[If known] Expect completion after steps X, Y, Z.
```

## Completion Report Format

Use when finishing your assigned work:

```markdown
## Complete: [Task Name]

### Summary
Brief description of what was accomplished.

### Changes

**Created:**
- `path/to/new/file.dart` - Purpose

**Modified:**
- `path/to/file.dart:45-60` - What changed

**Deleted:**
- `path/to/old/file.dart` - Why removed

### Verification
- ✅ Analysis: Clean (0 errors, 0 warnings)
- ✅ Tests: All passing (15/15)
- ✅ Manual verification: [If applicable]

### Notes
- Any caveats or follow-up items
- Decisions made during implementation
- Anything the next person should know

### Ready For
[Next step: review / testing / deployment / done]
```

## When to Report

### Always Report:
- Task completion
- Significant milestones
- Blockers (immediately)
- Unexpected findings

### Don't Over-Report:
- Every small step (unless asked)
- "Still working on it" with no new info
- Obvious progress that's visible in other ways

## Report Quality Checklist

Before sending a report, verify:

- [ ] **Specific**: Contains concrete details, not vague statements
- [ ] **Actionable**: Clear what happens next
- [ ] **Honest**: Includes problems, not just successes
- [ ] **Complete**: All relevant info included
- [ ] **Concise**: No unnecessary filler

## Good vs Bad Reports

### ❌ Bad Completion Report
```
"Done with the auth stuff. Let me know if you need anything else."
```
- What specifically was done?
- What files changed?
- Did verification pass?
- What's the next step?

### ✅ Good Completion Report
```markdown
## Complete: Auth Middleware Implementation

### Summary
Implemented JWT validation middleware for protected routes.

### Changes
**Created:**
- `lib/middleware/auth_middleware.dart` - JWT validation logic
- `test/middleware/auth_middleware_test.dart` - Unit tests

**Modified:**
- `lib/routes/api_routes.dart:23-45` - Applied middleware to protected routes

### Verification
- ✅ Analysis: Clean
- ✅ Tests: 8/8 passing
- ✅ Manual: Tested with valid/invalid/expired tokens

### Notes
- Used existing JwtService for token validation
- Added 401 response for invalid tokens, 403 for insufficient permissions

### Ready For
Testing with real auth flow
```

## Reporting Cadence by Team

Different teams have different reporting expectations:

| Team | Progress Updates | Completion Reports |
|------|------------------|-------------------|
| Startup | On completion only | Brief |
| Balanced | On milestones | Standard |
| Enterprise | Continuous | Comprehensive |
| Research | Continuous (findings) | Detailed |
