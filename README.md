<h1 align="center">
  <img src="docs/logo.png" alt="Vide Logo" height="50" style="vertical-align: middle;"/>
  Vide
</h1>

<p align="center">
  <strong>Multi-agent orchestration for Claude Code</strong>
</p>

<p align="center">
  <a href="https://github.com/Norbert515/vide_cli/actions/workflows/test.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/Norbert515/vide_cli/test.yml?branch=main&style=for-the-badge&logo=github&label=Tests" alt="Tests"/>
  </a>
  <a href="https://github.com/Norbert515/vide_cli/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-Apache%202.0-blue?style=for-the-badge" alt="License"/>
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey?style=for-the-badge" alt="Platform"/>
</p>

Instead of a single Claude conversation, Vide orchestrates a **team of specialized agents** that spawn, communicate, and work in parallel—each with distinct responsibilities.

```
         You
          │
          ▼
   ┌─────────────┐
   │ Orchestrator │  ← Assesses, clarifies, delegates (never writes code)
   └──────┬──────┘
          │ spawns
    ┌─────┼─────┐
    ▼     ▼     ▼
  ┌───┐ ┌───┐ ┌───┐
  │ R │ │ I │ │ T │   ← Researcher, Implementer, Tester
  └───┘ └───┘ └───┘
          │
    async message
       passing
```

---

## Install

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/Norbert515/vide_cli/main/scripts/install.sh | bash

# Windows
irm https://raw.githubusercontent.com/Norbert515/vide_cli/main/scripts/install.ps1 | iex
```

Requires [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`).

Then run:

```bash
vide
```

---

## License

[Apache License 2.0](LICENSE)
