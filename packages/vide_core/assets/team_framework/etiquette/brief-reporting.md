---
name: brief-reporting
description: Minimal reporting for high-throughput agents
applies-to: test-runner, worker
---

# Brief Reporting Protocol

For agents optimized for speed and parallel execution. Report outcomes, not process.

## Core Principle

**If it works, say so. If it doesn't, say why. Nothing else.**

## Report Formats

### Success
```
✅ PASS
```

### Failure
```
❌ FAIL: [One-line description of what failed]
```

### Blocked
```
❌ BLOCKED: [One-line reason why tests couldn't run]
```

## Examples

### ✅ Good Reports

```
✅ PASS
```

```
❌ FAIL: Login button doesn't navigate to dashboard
```

```
❌ FAIL: Form accepts invalid email format
```

```
❌ BLOCKED: App crashes on startup - null pointer in main.dart:45
```

### ❌ Bad Reports

```
I tested the login flow by entering a username and password,
then clicking the login button. The app successfully navigated
to the dashboard screen where I could see the user's profile.
Everything appears to be working correctly!
```
→ Too verbose. Just say `✅ PASS`

```
❌ FAIL
```
→ Missing the reason. What failed?

```
I noticed that the login button has a slight delay before responding,
and the loading indicator could be improved. Also, the error messages
aren't very user-friendly. You might want to consider...
```
→ Not a test report. Suggestions belong elsewhere.

## When to Add Detail

Only expand beyond PASS/FAIL when:
- Multiple distinct failures occurred (list each)
- Error message is critical for debugging
- Failure is ambiguous without context

### Multiple Failures
```
❌ FAIL:
- Back button doesn't navigate
- Form doesn't clear on submit
- Keyboard doesn't dismiss
```

### Critical Error
```
❌ BLOCKED: App crashed
Error: Null check operator used on null value
Stack: lib/services/auth.dart:89
```

## Don't Include

- ❌ What you did step by step
- ❌ Suggestions for improvements
- ❌ Praise or criticism of the code
- ❌ Offers to help further
- ❌ Questions about next steps
