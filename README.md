[![CI](https://github.com/Norbert515/vide_cli/actions/workflows/test.yml/badge.svg)](https://github.com/Norbert515/vide_cli/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](https://github.com/Norbert515/vide_cli)
[![Website](https://img.shields.io/badge/web-vide.dev-blue)](https://vide.dev)

<p align="center">
<img src="landing/assets/og-image.png" alt="Vide" width="600" />
</p>

<p align="center">
<a href="https://vide.dev"><strong>Website</strong></a> |
<a href="https://github.com/Norbert515/vide_cli"><strong>GitHub</strong></a>
</p>

**The open source meta-agent for vibe engineering.** Instead of one AI conversation, Vide orchestrates a team of specialized agents that research, implement, review, and test your code -- all working in parallel.

## Install

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/Norbert515/vide_cli/main/scripts/install.sh | bash

# Windows
irm https://raw.githubusercontent.com/Norbert515/vide_cli/main/scripts/install.ps1 | iex
```

Requires [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`).

Then just run:

```bash
vide
```

## Agent Teams, Not Single Agents

Most AI coding tools give you one agent in one conversation. Vide gives you a team.

A lead agent breaks down your request and spawns specialists -- researcher, implementer, tester -- that work in parallel across separate git worktrees. They communicate asynchronously and iterate through review rounds until the job is done.

<p align="center">
<img src="docs/hero.png" alt="Vide agent team in action" width="700" />
</p>

## Collaboration Built In

Agents don't just run in parallel -- they collaborate. The orchestrator delegates to an implementer, a QA agent reviews the result, issues get fixed, another round of review. This loop repeats until quality is met.

Structured engineering workflows, not just autocomplete.

## Remote Control

REST API with WebSocket streaming. Every agent's status, messages, and tool calls stream in real time -- control your agent teams from anywhere.

Mobile app coming soon.

## Multi-Backend

Vide doesn't call models directly -- it orchestrates full agent frameworks via their SDKs. Currently built on Claude Code. Codex CLI and Gemini CLI are on the roadmap. Same agent teams, same workflows, always using the best each framework has to offer.

## Features

- **Flutter-first** -- hot reload, vision AI (Moondream), widget inspection, screenshot capture
- **Git worktrees** -- each feature team works on its own branch in isolation
- **Custom agents** -- drop `.md` files into `.claude/agents/` to define your own specialists
- **60fps terminal UI** -- a real TUI built on nocterm, not scrolling text
- **Open source** -- Apache 2.0. Extend with MCP servers. Build on top of it.

## License

[Apache License 2.0](LICENSE)
