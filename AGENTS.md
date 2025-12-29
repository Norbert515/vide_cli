# Repository Guidelines

## Project Structure & Module Organization
- `bin/` contains CLI entrypoints (`vide.dart` is the main executable, `demo.dart` for demos).
- `lib/` holds the core application code, organized by `components/`, `modules/`, `services/`, and `utils/`.
- `packages/` contains internal packages (`claude_sdk`, `flutter_runtime_mcp`, `runtime_ai_dev_tools`, `moondream_api`).
- `test/` includes unit and integration tests, generally mirroring module locations under `lib/`.
- `docs/` stores assets used in the README (logo, hero image).
- `scripts/` contains install scripts for macOS/Linux/Windows.
- `specs/` and `videdev/` hold product specs and developer tooling notes.

## Build, Test, and Development Commands
- `dart pub get` installs dependencies.
- `dart run bin/vide.dart` runs the CLI from source.
- `dart compile exe bin/vide.dart -o vide` builds a native binary.
- `just compile` wraps the compile steps; `just install` copies the binary to `~/.local/bin`.
- `just generate-devtools` regenerates bundled devtools after editing `packages/runtime_ai_dev_tools`.
- `dart test` runs the full test suite (use `dart test test/utils/...` for a focused run).

## Coding Style & Naming Conventions
- Dart uses 2-space indentation and standard Dart formatting; run `dart format .` before committing.
- Linting is configured in `analysis_options.yaml`; run `dart analyze` for static checks.
- Files use `lower_snake_case.dart`; classes use `UpperCamelCase`; variables/functions use `lowerCamelCase`.
- Prefer small, single-purpose modules in `lib/modules/` and shared helpers in `lib/utils/`.

## Testing Guidelines
- Tests use the `package:test` framework.
- Name tests `*_test.dart` and keep tests close to the feature area (for example, `test/modules/...`).
- Cover core CLI behavior and parsing logic; add regression tests when fixing bugs.

## Commit & Pull Request Guidelines
- Commit messages in this repo are short, imperative, and sentence case (examples: "Add tests for diff renderer", "Fix: Package macOS binary").
- Keep commits focused and avoid unrelated refactors.
- PRs should include a clear summary, list of tests run, and linked issues when applicable.
- Add screenshots or terminal captures for user-facing TUI/CLI changes.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
