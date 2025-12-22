# Vide CLI - Developer Context

## Project Overview

**Vide CLI** is an agentic terminal UI for Claude Code, specifically designed to accelerate Flutter development. It orchestrates a network of specialized agents (Implementation, Context, Tester, Planning) that collaborate asynchronously to perform complex tasks.

Key capabilities include:
*   **Multi-Agent Orchestration:** A main orchestrator delegates tasks to specialized sub-agents.
*   **Flutter Runtime Integration:** Injects tools into running Flutter apps to enable "vision-based" testing (screenshots, semantic tapping via Moondream AI).
*   **Persistent Memory:** Remembers project context and user preferences across sessions.
*   **Git Worktree Support:** Manages isolated environments for feature development.

## Tech Stack

*   **Language:** Dart (SDK ^3.8.0)
*   **Frameworks:**
    *   **UI:** `nocterm` (Custom TUI framework, similar to Flutter's widget tree but for terminals).
    *   **State Management:** `riverpod` (Extensively used).
    *   **Architecture:** Model Context Protocol (MCP) servers used for modular tool exposure.
*   **Internal Packages:**
    *   `packages/flutter_runtime_mcp`: The core engine for controlling Flutter apps.
    *   `packages/claude_api`: Wrapper for Claude Code API.
    *   `packages/runtime_ai_dev_tools`: The code injected into the target Flutter app.

## Build and Run

### Prerequisites
*   Dart SDK ^3.8.0
*   `just` (command runner) - Optional but recommended.

### Commands

| Action | Command | Description |
| :--- | :--- | :--- |
| **Install Dependencies** | `dart pub get` | Fetch packages. |
| **Run (Dev)** | `dart run bin/vide.dart` | Run locally from source. |
| **Build Binary** | `just compile` | Compiles to native executable `./vide`. |
| **Install Globally** | `just install` | Compiles and moves to `~/.local/bin/vide`. |
| **Run Tests** | `dart test` | Run all tests. |
| **Code Generation** | `dart run build_runner build` | Run for `freezed`, `json_serializable`, `riverpod`. |
| **Regen DevTools** | `just generate-devtools` | Run after modifying `packages/runtime_ai_dev_tools`. |

## Project Structure

*   **`bin/`**: Application entry points (`vide.dart`).
*   **`lib/`**:
    *   **`components/`**: UI widgets for the TUI (using `nocterm`).
    *   **`modules/`**:
        *   **`agent_network/`**: Core logic for agent spawning, status, and messaging.
        *   **`agents/`**: Configurations and prompts for different agent types.
        *   **`mcp/`**: Implementations of MCP servers (Git, Memory, Flutter Runtime).
        *   **`permissions/`**: Handling user permissions for tool execution.
        *   **`settings/`**: Parsing/managing local settings (`.claude/settings.local.json`).
*   **`packages/`**: Monorepo-style internal packages.
    *   **`flutter_runtime_mcp/`**: Critical package for Flutter app control.
    *   **`runtime_ai_dev_tools/`**: The "payload" injected into user apps.

## Development Conventions

*   **Style:** Standard Dart style. Run `dart format .` before committing.
*   **Testing:** Use `package:test`. **Do not** use try-catch blocks in tests; let failures bubble up.
*   **Architecture:**
    *   Agents communicate via **asynchronous message passing**.
    *   Use `riverpod` for state.
    *   **Permissions:** All "dangerous" actions (shell commands, file writes) must go through the permission matcher (`lib/modules/permissions/`).
*   **Git:** Commit messages should be short, imperative, and sentence case (e.g., "Add feature X", "Fix bug Y").

## Key Workflows for Contributors

1.  **Modifying Agents:** Edit prompts in `lib/modules/agents/configs/`.
2.  **Modifying Runtime Injection:**
    *   Edit `packages/runtime_ai_dev_tools`.
    *   Run `just generate-devtools` to bundle the changes into `flutter_runtime_mcp`.
    *   Recompile Vide.
3.  **Adding MCP Tools:** Implement in the relevant server under `lib/modules/mcp/`.

## Debugging

*   **Logs:** `print` is allowed in this CLI app for outputting to the terminal/logs.
*   **Analysis:** Run `dart analyze` frequently to catch issues.
