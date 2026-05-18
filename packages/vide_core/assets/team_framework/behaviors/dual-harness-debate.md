---
name: dual-harness-debate
description: Protocol for spawning parallel agents on different harnesses and facilitating direct debates
---

# Dual-Harness Debate Protocol

When a task benefits from multiple perspectives, spawn the SAME agent type on TWO DIFFERENT harnesses (claude-code and codex-cli) and let them debate.

## The Principle

**Two models, one problem. Let them argue — the truth emerges from the friction.**

Different LLM backends have different strengths, blind spots, and reasoning styles. Running them in parallel and having them directly challenge each other produces higher-quality analysis than either alone.

## When to Use Dual-Harness Debates

- Requirements analysis (different interpretations of the problem)
- Architecture design (different solution approaches)
- Code review (different things catch different eyes)
- Risk assessment (different failure modes spotted)

## The Debate Protocol

### Step 1: Parallel Research

Spawn two agents of the same type with different harnesses:

```dart
// Agent A — Claude Code backend
spawnAgent(
  agentType: "requirements-analyst",
  harness: "claude-code",
  name: "Requirements Analysis (Claude)",
  initialPrompt: """
[Task description]

## Instructions
Complete your analysis independently. Do NOT try to be balanced or
hedge — commit to your strongest interpretation.

When done, report your findings to me.
"""
)

// Agent B — Codex backend (parallel)
spawnAgent(
  agentType: "requirements-analyst",
  harness: "codex-cli",
  name: "Requirements Analysis (Codex)",
  initialPrompt: """
[Same task description]

## Instructions
Complete your analysis independently. Do NOT try to be balanced or
hedge — commit to your strongest interpretation.

When done, report your findings to me.
"""
)

setAgentStatus("waitingForAgent")
// ⛔ STOP. Wait for both agents to report back.
```

### Step 2: Initiate the Debate

Once BOTH agents have reported back, send each agent the other's findings and instruct them to debate:

```dart
// Send Agent B's findings to Agent A
sendMessageToAgent(
  targetAgentId: "{agent-a-id}",
  message: """
## Debate Round 1

Your counterpart (running on a different model) produced this analysis:

---
{Agent B's full report}
---

## Your Task
1. Identify where you AGREE — acknowledge valid points
2. Identify where you DISAGREE — explain why with evidence
3. Identify what they MISSED that you caught
4. Identify what they FOUND that you missed — be honest
5. Send your critique directly to your counterpart: {agent-b-id}
6. Also send a copy to me: {lead-id}
"""
)

// Send Agent A's findings to Agent B
sendMessageToAgent(
  targetAgentId: "{agent-b-id}",
  message: """
## Debate Round 1

Your counterpart (running on a different model) produced this analysis:

---
{Agent A's full report}
---

## Your Task
1. Identify where you AGREE — acknowledge valid points
2. Identify where you DISAGREE — explain why with evidence
3. Identify what they MISSED that you caught
4. Identify what they FOUND that you missed — be honest
5. Send your critique directly to your counterpart: {agent-a-id}
6. Also send a copy to me: {lead-id}
"""
)

setAgentStatus("waitingForAgent")
// ⛔ STOP. Wait for debate round 1 to complete.
```

### Step 3: Monitor the Debate (2-3 Rounds)

The agents message each other directly. Each round:
- Agent reads the other's critique
- Responds with counter-arguments or concessions
- Sends a copy to the lead

**Stop the debate when:**
- Agents reach consensus on key points (2 rounds usually enough)
- 3 rounds have passed (hard limit — diminishing returns)
- One agent clearly concedes on a major point

### Step 4: Synthesize

After the debate ends, the lead synthesizes:

```markdown
## Debate Synthesis: [Topic]

### Points of Consensus
- [Both agents agreed on X]
- [Agent A conceded Y after Agent B's argument]

### Unresolved Disagreements
- [Issue]: Agent A says X because [reason]. Agent B says Y because [reason].
  → **Lead's decision**: [Your call, with justification]

### Key Insights from Debate
- [Something neither would have found alone]
- [Blind spot one agent caught in the other's work]

### Final Position
[The synthesized view that takes the best from both]
```

## Rules for Debate Agents

When participating in a debate:

1. **Be adversarial, not agreeable** — Your job is to find flaws, not validate. Challenge assumptions, question evidence, probe edge cases.
2. **Be honest about your weaknesses** — If the other agent found something you missed, acknowledge it clearly.
3. **Cite evidence** — Don't just disagree; point to specific code, files, or logic that supports your position.
4. **Stay focused** — Debate the substance, not meta-discussion about the debate itself.
5. **Converge when warranted** — If the other agent makes a compelling argument, update your position. Stubborn disagreement for its own sake wastes cycles.

## Harness Configuration

The debate protocol requires both `claude-code` and `codex-cli` harnesses to be available. The lead spawns agents with explicit `harness` overrides:

- **Claude Code agents**: `harness: "claude-code"` — Anthropic Claude backend
- **Codex agents**: `harness: "codex-cli"` — OpenAI Codex backend

If the codex-cli harness is not available (not configured), fall back to spawning two claude-code agents with a note that dual-model debate is degraded to single-model parallel analysis.
