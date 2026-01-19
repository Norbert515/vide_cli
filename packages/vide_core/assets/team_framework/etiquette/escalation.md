---
name: escalation
description: When and how to escalate issues
applies-to: all
---

# Escalation Protocol

Know when to ask for help vs. push through. Escalating appropriately prevents wasted effort and catches issues early.

## When to Escalate

### Escalate to Parent Agent When:

1. **Blocked for 5+ minutes** on something that should be straightforward
2. **Tried 2+ approaches** without success
3. **Missing information** that isn't in the codebase
4. **Scope question** - unsure if something is in/out of scope
5. **Found unexpected complexity** that changes the approach
6. **Need a decision** between valid alternatives

### Escalate to User When:

1. **Security implications** discovered
2. **Multiple valid approaches** with significant trade-offs
3. **Missing requirements** that can't be inferred
4. **Scope change recommended** based on findings
5. **Breaking changes** that affect other systems
6. **Data or privacy concerns**

## How to Escalate

### Format for Agent-to-Agent Escalation

```markdown
## Escalation: [Brief Title]

### Situation
What I was trying to do.

### Problem
What's blocking me.

### Attempted
1. First thing I tried → Result
2. Second thing I tried → Result

### Need
What I need to proceed:
- [ ] Decision on X
- [ ] Information about Y
- [ ] Access to Z

### Recommendation (if any)
If you have a suggestion, include it.
```

### Format for User Escalation

```markdown
## Need Your Input: [Brief Title]

### Context
What we're working on and why this came up.

### Question
The specific thing we need you to decide/clarify.

### Options (if applicable)

**Option A: [Name]**
- Approach: ...
- Pros: ...
- Cons: ...

**Option B: [Name]**
- Approach: ...
- Pros: ...
- Cons: ...

### Recommendation
[If you have one] We suggest Option X because...

### Impact of Delay
What happens if we can't proceed (if relevant).
```

## Escalation Anti-Patterns

### ❌ Don't Do This

**Premature escalation**
```
"I don't know how to do this" (without trying)
```

**Vague escalation**
```
"I'm stuck" (no context or specifics)
```

**Escalating decisions you should make**
```
"Should I use tabs or spaces?" (follow existing patterns)
```

**Hiding bad news**
```
[Struggling silently for 30 minutes instead of asking for help]
```

### ✅ Do This Instead

**Try first, then escalate with context**
```markdown
## Escalation: Can't find session storage interface

### Situation
Implementing auth middleware, need to access session data.

### Problem
Can't find where sessions are stored/accessed.

### Attempted
1. Searched for "session" → Found SessionModel but no storage
2. Checked auth_service.dart → Uses sessions but doesn't show storage
3. Looked for Redis/database config → Nothing obvious

### Need
- Where is session data stored?
- Is there an existing interface I should use?
```

## Escalation Response Expectations

When you escalate:
- **Stay available** - Be ready for follow-up questions
- **Don't block on it** - Work on something else if possible
- **Acknowledge the response** - Confirm you received and understood

When responding to escalation:
- **Respond promptly** - Someone is blocked
- **Be specific** - Give actionable guidance
- **Follow up** - Check if it resolved the issue
