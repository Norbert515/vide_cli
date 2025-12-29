# REST API Architecture Plan for Vide CLI

## 🎯 Current Status

**Phase 1: COMPLETE ✅** (Completed: December 21, 2025)
- Extracted `vide_core` package with all shared business logic
- Updated TUI to use `vide_core` via provider overrides
- All 225 tests passing
- `dart analyze` clean (no issues)
- TUI compiles and runs successfully

**Phase 2: IN PROGRESS 🔄** (Started: December 2025)
- ✅ Created `vide_server` package with WebSocket streaming
- ✅ Implemented POST /api/v1/networks endpoint
- ✅ Implemented POST /api/v1/networks/{networkId}/messages endpoint
- ✅ Implemented WebSocket streaming at /api/v1/networks/{networkId}/agents/{agentId}/stream
- ✅ Fixed duplicate content bug in WebSocket streaming (see Bug Fixes below)
- ✅ Added integration tests for end-to-end flow and duplicate content detection
- ⬜ Multi-turn conversation test has pre-existing flakiness (timeout issues)

**Phase 3: NOT STARTED** (Final: Testing & Documentation)

### Bug Fixes (Phase 2)

**Duplicate Content in WebSocket Streaming** (Fixed: December 28, 2025)

*Issue 1: Cumulative vs Partial Message Handling*
- **Problem**: WebSocket stream was sending duplicate content (e.g., 18 chars instead of 9)
- **Root Cause**: Claude CLI sends BOTH streaming deltas (`content_block_delta`) AND cumulative assistant messages (`type: 'assistant'`). The `TextResponse.fromAssistantMessage` factory incorrectly marked cumulative messages as `isPartial: true` when `stop_reason` was null.
- **Fix**: Changed `fromAssistantMessage` to set `isPartial: false` and added filtering in `ConversationMessage.assistant` to prefer partial (delta) responses when present.

*Issue 2: Race Condition in Control Protocol Startup*
- **Problem**: Messages were still being processed twice even after Issue 1 fix
- **Root Cause**: When using `ClaudeClient.createNonBlocking()` followed by `sendMessage()`, both `init()` and `sendMessage()` could call `_startControlProtocol()` concurrently. Since `Process.start()` is async, both calls could pass the `_activeProcess != null` check before either set it, resulting in **two Claude CLI processes** running simultaneously, each with its own subscription to the messages stream.
- **Fix** (`packages/claude_sdk/lib/src/client/claude_client.dart`): Added `_startingControlProtocol` future guard to make the startup idempotent - concurrent callers await the same in-progress startup instead of starting a new one.
- **Tests**: Added integration tests for streaming with tool use, rapid sequential messages, and tool event ordering

---

## Overview
Transform Vide CLI from a pure TUI application into a dual-interface architecture supporting both CLI (text UI) and Web (REST API backend). The REST API server will run as a separate process, exposing core functionality via HTTP endpoints for building a web frontend.

## User Requirements
- **Architecture**: Separate processes - REST API server runs independently from TUI
- **Security**: None for MVP (localhost testing only) - add authentication post-MVP
- **Sessions**: Separate agent network sessions - REST and TUI don't share state
- **Scope**: Minimal MVP - Start session with prompt, get agent response via SSE streaming
- **Server binding**: Bind to loopback only and auto-select an unused port; print full URL on startup

## Implementation Decisions (from user Q&A)
- **Network tracking**: Hybrid approach - cache loaded networks in memory for performance
- **Agent ID exposure**: Return `mainAgentId` in POST /networks response for immediate streaming
- **Permission system**: Create `PermissionProvider` interface in vide_core (abstraction layer)
- **PostHogService init**: Pass `VideConfigManager` instance via provider (not String)
- **Sub-agent streaming**: Multiplex all network activity into main agent's stream
- **Message concurrency**: Queue messages (already built-in to ClaudeClient's `_inbox`)
- **Package dependencies**: Use path dependencies for local packages (vide_core, flutter_runtime_mcp, etc.)
- **nocterm_riverpod**: Confirmed safe to replace in vide_core (just a wrapper with TUI-specific extensions)

## Architecture Strategy

### Package Structure
Extract shared core package while keeping vide_cli at repo root:

```
vide_cli/ (repo root)
├── bin/                   # STAYS: CLI entry point
├── lib/                   # STAYS: TUI-specific code (slimmed down)
├── test/                  # STAYS: TUI tests
├── pubspec.yaml           # UPDATED: Add vide_core dependency
├── packages/
│   ├── vide_core/         # NEW: Shared business logic (models, services)
│   ├── vide_server/       # NEW: REST API server
│   ├── flutter_runtime_mcp/ # EXISTING: stays here
│   ├── claude_sdk/        # EXISTING: stays here
│   └── moondream_api/     # EXISTING: stays here
```

**Rationale**: Single source of truth for business logic. Both TUI and REST API depend on vide_core. Bug fixes and features benefit both implementations immediately. No disruption to existing build/deployment infrastructure.

**Key principle**: DRY (Don't Repeat Yourself). Shared code lives in vide_core, UI-specific code stays in vide_cli at root.

### Session Isolation Strategy
Use UI-scoped persistence directories to completely isolate REST and TUI sessions:

```
TUI:  ~/.vide/projects/{encoded-path}/
REST: ~/.vide/api/projects/{encoded-path}/
```

**Note**: No user isolation for MVP since there's no authentication. Post-MVP will add user-scoped directories.

This prevents any conflicts between CLI and web users working on the same project.

## Implementation Plan

### Phase 1: Extract Core Business Logic (~3-4 hours)

**IMPORTANT**: Use `git mv` for ALL file moves to preserve git history!

#### 1.1 Create `packages/vide_core/` Package
**New Files:**
- `packages/vide_core/pubspec.yaml`
- `packages/vide_core/lib/vide_core.dart` (barrel export - exports all models, services, agents, mcp, utils, state)

**Dependencies** (replace `nocterm_riverpod` imports with `riverpod` when moving files to vide_core):
```yaml
dependencies:
  claude_sdk:
    path: ../claude_sdk
  flutter_runtime_mcp:
    path: ../flutter_runtime_mcp
  riverpod: ^3.0.3
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  uuid: ^4.0.0
  path: ^1.8.3
  http: ^1.1.0

dev_dependencies:
  build_runner: ^2.4.6
  freezed: ^2.4.5
  json_serializable: ^6.7.1
  test: ^1.24.9
```

**Note**: No separate analysis_options.yaml needed - root analysis_options.yaml applies to all packages

#### 1.2 Move Models to `vide_core`
**Move these files** using `git mv` to preserve history:
```bash
mkdir -p packages/vide_core/lib/models
git mv lib/modules/agent_network/models/agent_network.dart packages/vide_core/lib/models/agent_network.dart
git mv lib/modules/agent_network/models/agent_metadata.dart packages/vide_core/lib/models/agent_metadata.dart
git mv lib/modules/agent_network/models/agent_id.dart packages/vide_core/lib/models/agent_id.dart
git mv lib/modules/agent_network/models/agent_status.dart packages/vide_core/lib/models/agent_status.dart
git mv lib/modules/memory/model/memory_entry.dart packages/vide_core/lib/models/memory_entry.dart
```

**Changes required**: None to the models themselves - they're already pure data classes with freezed.

#### 1.2.1 Run Code Generation
**After moving models**, generate freezed/json_serializable code:
```bash
cd packages/vide_core
dart run build_runner build --delete-conflicting-outputs
```

**Note**: This generates `.g.dart` and `.freezed.dart` files for the models.

#### 1.3 Move MemoryService to `vide_core`
**Move file** using `git mv`:
```bash
mkdir -p packages/vide_core/lib/services
git mv lib/modules/memory/memory_service.dart packages/vide_core/lib/services/memory_service.dart
```

**Changes required**: None - move AS-IS including the Riverpod provider

#### 1.4 Move VideConfigManager to `vide_core`
**Move file** using `git mv`:
```bash
git mv lib/services/vide_config_manager.dart packages/vide_core/lib/services/vide_config_manager.dart
```

**Changes**: Convert from singleton to Riverpod provider
- Remove singleton pattern (factory constructor → normal constructor)
- Add `configRoot` parameter to constructor
- Remove `initialize()` method - initialization happens at construction
- Create provider:
```dart
final videConfigManagerProvider = Provider<VideConfigManager>((ref) {
  throw UnimplementedError('VideConfigManager must be overridden by UI');
});
```

**UI Implementation**:
- **TUI**: Override provider with `configRoot = ~/.vide`
- **REST**: Override provider with `configRoot = ~/.vide/api`

**Rationale**: Uses Riverpod dependency injection instead of modifying core logic. Zero changes to business logic!

#### 1.5 Move PostHogService to `vide_core`
**Move file** using `git mv`:
```bash
git mv lib/services/posthog_service.dart packages/vide_core/lib/services/posthog_service.dart
```

**Changes**:
- Update `init()` to accept `Ref` parameter and use `ref.read(videConfigManagerProvider)` to access config (instead of singleton)
- This allows PostHogService to use dependency injection via Riverpod providers

#### 1.6 Create Permission Provider Abstraction
**New file**: `packages/vide_core/lib/models/permission.dart` (~40 lines)

**Purpose**: Extract permission data classes and create abstraction for both TUI and REST

**Approach**:
1. **Extract** `PermissionRequest` and `PermissionResponse` from `lib/modules/permissions/permission_service.dart`
2. Create new file `packages/vide_core/lib/models/permission.dart` with these classes (copy, not `git mv`, since they're within a file)
3. Update `lib/modules/permissions/permission_service.dart` to import from vide_core and remove local class definitions

**New file**: `packages/vide_core/lib/services/permission_provider.dart` (~20 lines)

**Purpose**: Abstract interface for permission requests

**Key Classes**:
- `PermissionProvider` - Abstract interface:
  ```dart
  abstract class PermissionProvider {
    /// Request permission for a tool invocation
    Future<PermissionResponse> requestPermission(PermissionRequest request);
  }
  ```
- `permissionProvider` - Riverpod provider:
  ```dart
  final permissionProvider = Provider<PermissionProvider>((ref) {
    throw UnimplementedError('PermissionProvider must be overridden by UI');
  });
  ```

**Implementation Strategy**:
- TUI: Create adapter that wraps existing `PermissionService` HTTP server + dialog UI, implements `PermissionProvider`
- REST: Create `SimplePermissionService` with auto-approve/deny rules, implements `PermissionProvider`

**Rationale**: Allows vide_core to request permissions without knowing how they're granted. Each UI implements the provider differently.

#### 1.7 Move AgentNetworkPersistenceManager to `vide_core`
**Move file** using `git mv`:
```bash
git mv lib/modules/agent_network/service/agent_network_persistence_manager.dart packages/vide_core/lib/services/agent_network_persistence_manager.dart
```

**Changes**: None - move AS-IS including the Riverpod provider

#### 1.8 Move Agent Configurations and Loader to `vide_core`
**Move files** using `git mv`:
```bash
mkdir -p packages/vide_core/lib/agents
# Agent configurations
git mv lib/modules/agents/models/agent_configuration.dart packages/vide_core/lib/agents/agent_configuration.dart
git mv lib/modules/agents/models/user_defined_agent.dart packages/vide_core/lib/agents/user_defined_agent.dart
git mv lib/modules/agents/agent_loader.dart packages/vide_core/lib/agents/agent_loader.dart
git mv lib/modules/agents/configs/main_agent_config.dart packages/vide_core/lib/agents/main_agent_config.dart
git mv lib/modules/agents/configs/implementation_agent_config.dart packages/vide_core/lib/agents/implementation_agent_config.dart
git mv lib/modules/agents/configs/context_collection_agent_config.dart packages/vide_core/lib/agents/context_collection_agent_config.dart
git mv lib/modules/agents/configs/planning_agent_config.dart packages/vide_core/lib/agents/planning_agent_config.dart
git mv lib/modules/agents/configs/flutter_tester_agent_config.dart packages/vide_core/lib/agents/flutter_tester_agent_config.dart
git mv lib/modules/agents/configs/prompt_sections packages/vide_core/lib/agents/prompt_sections
```

**Changes**: Remove any nocterm-specific imports. These are pure data classes.

**Rationale**: Both TUI and REST should be able to load custom agents from `.claude/agents/*.md` files.

#### 1.9 Move Shared Utilities to `vide_core`
**Move these files** using `git mv`:
```bash
mkdir -p packages/vide_core/lib/utils
git mv lib/utils/project_detector.dart packages/vide_core/lib/utils/project_detector.dart
git mv lib/utils/system_prompt_builder.dart packages/vide_core/lib/utils/system_prompt_builder.dart
git mv lib/utils/working_dir_provider.dart packages/vide_core/lib/utils/working_dir_provider.dart
```

**Changes to `working_dir_provider.dart`**:
- Update the provider to throw `UnimplementedError` (like other providers in vide_core):
  ```dart
  final workingDirProvider = Provider<String>((ref) {
    throw UnimplementedError('workingDirProvider must be overridden by UI');
  });
  ```
- **TUI** will override with implementation that returns `path.current`
- **REST** will override with implementation that throws descriptive error: "Working directory must be explicitly provided for REST API - do not use default"

**Rationale**: Forces each UI to explicitly provide working directory strategy, preventing accidental use of implicit defaults.

#### 1.10 Move AgentNetworkManager to `vide_core`
**Move file** using `git mv`:
```bash
git mv lib/modules/agent_network/service/agent_network_manager.dart packages/vide_core/lib/services/agent_network_manager.dart
```

**Changes**:
- Replace `package:nocterm_riverpod/nocterm_riverpod.dart` with `package:riverpod/riverpod.dart`
- Update `startNew()` signature to accept optional `workingDirectory` parameter:
  ```dart
  Future<AgentNetwork> startNew(Message initialMessage, {String? workingDirectory}) async {
    final networkId = const Uuid().v4();
    final mainAgentId = const Uuid().v4();

    // ... create agent metadata ...

    final network = AgentNetwork(
      id: networkId,
      goal: taskDisplayName,
      agents: [mainAgentMetadata],
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      worktreePath: workingDirectory, // Atomically set working directory from parameter
    );

    // ... persist, start agent, and return ...
  }
  ```
- When `workingDirectory` is provided (REST API), it's atomically set as `worktreePath` in the network
- When `workingDirectory` is null (TUI default), `worktreePath` is null and `effectiveWorkingDirectory` falls back to `workingDirectory` from provider
- Both TUI and REST use the same API: TUI omits parameter (uses CWD from provider), REST passes user's directory explicitly

**Rationale**: Single atomic operation during network creation. REST always provides working directory explicitly; TUI relies on provider fallback. Clean separation of concerns.

**Note**: nocterm_riverpod is safe to replace - it's a wrapper that adds nocterm-specific BuildContext extensions. The core Riverpod features (Provider, StateNotifierProvider, ProviderContainer) are identical to standard riverpod.

#### 1.11 Move MCP Servers to vide_core (keep flutter_runtime_mcp)
**Move directories** using `git mv`:
```bash
mkdir -p packages/vide_core/lib/mcp
git mv lib/modules/mcp/memory packages/vide_core/lib/mcp/memory
git mv lib/modules/mcp/agent packages/vide_core/lib/mcp/agent
git mv lib/modules/mcp/task_management packages/vide_core/lib/mcp/task_management
git mv lib/modules/mcp/git packages/vide_core/lib/mcp/git
```

**Note**: `packages/flutter_runtime_mcp/` stays in place; add path dependency in `packages/vide_core/pubspec.yaml`:
```yaml
dependencies:
  flutter_runtime_mcp:
    path: ../flutter_runtime_mcp
```

**Changes**: Move MCP servers AS-IS.

**Rationale**: Centralize non-TUI MCP logic in vide_core while keeping `flutter_runtime_mcp` as a sibling package. Goal is feature-for-feature equivalent web UI eventually.

#### 1.12 Move ClaudeManager and AgentStatusManager to vide_core
**Move files** using `git mv`:
```bash
mkdir -p packages/vide_core/lib/state
git mv lib/modules/agent_network/service/claude_manager.dart packages/vide_core/lib/services/claude_manager.dart
git mv lib/modules/agent_network/state/agent_status_manager.dart packages/vide_core/lib/state/agent_status_manager.dart
```

**Changes**: None - move AS-IS including Riverpod providers

**Rationale**: These are core orchestration services used by AgentNetworkManager. Need them in vide_core for the REST API.

#### 1.13 Update vide_cli to use vide_core
**Modify**: `pubspec.yaml` - Add dependency (path dependency):
```yaml
dependencies:
  vide_core:
    path: packages/vide_core
```

**Update imports** in all files that used moved code:
- Replace `package:vide_cli/modules/agent_network/models/...` with `package:vide_core/models/...`
- Replace `package:vide_cli/modules/agent_network/service/...` with `package:vide_core/services/...`
- Replace `package:vide_cli/modules/mcp/...` with `package:vide_core/mcp/...`
- Replace `package:vide_cli/services/vide_config_manager.dart` with `package:vide_core/services/vide_config_manager.dart`
- Etc.

**Update calls to `startNew()`**:
- TUI keeps existing calls as-is: `startNew(initialMessage)`
- The `workingDirectory` parameter is optional and defaults to null
- When null, `effectiveWorkingDirectory` uses the `workingDirectory` from provider (current directory)

**Create TUI Permission Adapter**:
- Create `lib/modules/permissions/permission_service_adapter.dart`
- Implement `PermissionProvider` interface by wrapping existing `PermissionService`
- The adapter implements `requestPermission()` method using the existing HTTP server + dialog stream system
- Note: `PermissionRequest` and `PermissionResponse` are now in vide_core, so update TUI to use those

**Update TUI Entry Point**:
- Modify `bin/vide.dart`:
  - Initialize the `ProviderScope` with overrides:
    ```dart
    ProviderScope(
      overrides: [
        videConfigManagerProvider.overrideWithValue(VideConfigManager(configRoot: '~/.vide')),
        permissionProvider.overrideWithValue(TUIPermissionAdapter(permissionService)),
        workingDirProvider.overrideWith((ref) => path.current),  // Returns current directory
      ],
      child: VideApp(),
    )
    ```
  - Note: TUI calls to `startNew()` remain unchanged (omit `workingDirectory` parameter)

**Migrate Tests** (if any exist):
- If there are existing tests for moved services (AgentNetworkManager, MemoryService, etc.), move them to `packages/vide_core/test/` using `git mv`
- Update test imports to use `package:vide_core/...`
- Tests for TUI-specific code (permission dialogs, pages, components) stay in root `test/`

#### 1.13.1 Run Dart Analysis and Fix Issues
**Purpose**: Ensure the refactored code compiles and follows best practices

**Steps**:
1. Run analysis on vide_core (from repo root):
   ```bash
   dart analyze packages/vide_core
   ```
2. Fix all errors and warnings by addressing root causes (per CLAUDE.md - don't paper over issues)
3. Run analysis on entire project (from repo root):
   ```bash
   dart analyze
   ```
4. Fix all errors and warnings by addressing root causes
5. Verify both vide_core and vide_cli are error-free before proceeding

**Note**: This is a critical checkpoint. The project must be in a consistent, compilable state before moving to testing. Root analysis_options.yaml applies to all packages.

#### 1.14 Add Refactoring Verification Tests
**Purpose**: Ensure the new `vide_core` abstraction and dependency injection work correctly.

**New Tests in `packages/vide_core/test/`**:
- `test/config_isolation_test.dart`: Verify that `VideConfigManager` respects the injected `configRoot` path.
- `test/posthog_refactor_test.dart`: Verify that `PostHogService` initializes correctly with a provided config path (no singleton usage).
- `test/provider_override_test.dart`: Basic test to verify that `videConfigManagerProvider` throws `UnimplementedError` if not overridden, and works if overridden.

**Test Setup Pattern** (for all vide_core tests):
```dart
// Example test setup in vide_core/test/
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  test('example test with provider overrides', () {
    final container = ProviderContainer(
      overrides: [
        videConfigManagerProvider.overrideWithValue(
          VideConfigManager(configRoot: '/tmp/test-vide'),
        ),
        workingDirProvider.overrideWith((ref) => '/tmp/test-project'),
        permissionProvider.overrideWithValue(
          MockPermissionProvider(), // Test mock implementing PermissionProvider
        ),
      ],
    );

    // Test code using container.read(someProvider)

    container.dispose();
  });
}
```

**Note**: All providers in vide_core throw `UnimplementedError` by default, so tests MUST override them in a `ProviderContainer`.

---

### Phase 2: Build MVP REST Server (~2-3 hours) **AFTER PHASE 1 CHECKPOINT**

#### 2.1 Create `packages/vide_server/` Package
**New file**: `packages/vide_server/pubspec.yaml`

**Dependencies**:
```yaml
dependencies:
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  riverpod: ^3.0.3
  vide_core:
    path: ../vide_core
```

**Note**: No JWT, bcrypt, or auth dependencies for MVP!

#### 2.2 Implement Network Cache Manager
**New file**: `packages/vide_server/lib/services/network_cache_manager.dart` (~40 lines)

**Purpose**: Hybrid caching strategy - load networks from persistence on first access, then cache in memory

**Strategy**:
- Check in-memory cache first (O(1) lookup)
- If not cached, load from persistence
- Cache the loaded network for future requests
- Provides `invalidate()` method for cache clearing

**Rationale**: Balances performance (cached lookups) with statelessness (can restart server without losing state).

#### 2.3 Implement Server Entry Point
**New file**: `packages/vide_server/bin/vide_server.dart` (~100 lines)

**Responsibilities**:
- Parse CLI arguments (port only, optional)
- Create ProviderContainer with overrides:
  - VideConfigManager (configRoot = ~/.vide/api)
  - SimplePermissionService (auto-approve/deny rules)
  - workingDirProvider throws error (defensive - catches missing workingDirectory param)
- Create shelf HTTP server (bind loopback only)
- Set up middleware pipeline (CORS, logging only - no auth!)
- Mount routes
- Handle graceful shutdown
**Port selection**: If no port is provided, bind to port 0 and let the OS pick an unused port. Print the full URL (host:port) once bound.
**CLI option**: Support `--port` to request a specific port; otherwise default to ephemeral.

**Entry point**:
```dart
void main(List<String> args) async {
  final config = parseServerConfig(args);  // port only (optional)
  final container = ProviderContainer(overrides: [
    videConfigManagerProvider.overrideWithValue(
      VideConfigManager(configRoot: '~/.vide/api'),
    ),
    permissionProvider.overrideWithValue(
      SimplePermissionService(),
    ),
    // Defensive override: Fail fast if workingDirectory not passed to startNew()
    workingDirProvider.overrideWith((ref) {
      throw StateError(
        'Working directory must be explicitly provided for REST API - do not use default'
      );
    }),
  ]);

  final handler = createHandler(container);
  final server = await serve(handler, InternetAddress.loopbackIPv4, config.port ?? 0);

  print('Vide API Server: http://${server.address.host}:${server.port}');
  print('WARNING: No authentication - localhost only!');
}
```

#### 2.4 Implement Core Network API Endpoints (MVP)
**New file**: `packages/vide_server/lib/routes/network_routes.dart` (~200 lines)

**3 Core MVP Endpoints** (NO authentication for MVP):

1. **POST /api/v1/networks** - Create network and start agent
   ```
   Request:  {
     "initialMessage": "Write a hello world program",
     "workingDirectory": "/Users/chris/myproject"
   }
   Response: {
     "networkId": "uuid",
     "mainAgentId": "uuid",
     "createdAt": "2025-12-21T10:00:00Z"
   }
   ```
   **Requirements**:
   - `workingDirectory` is required for MVP
   - Response MUST include `mainAgentId` so client can open SSE stream immediately
   - `mainAgentId` is the first agent in the network (the orchestrator agent)

2. **POST /api/v1/networks/:networkId/messages** - Send message to agent
   ```
   Request:  {"content": "Now make it print goodbye too"}
   Response: {"status": "sent"}
   ```
   **Note**: Messages are automatically queued if agent is busy. ClaudeClient has built-in FIFO message queue (`_inbox`), so concurrent requests are handled sequentially.

3. **GET /api/v1/networks/:networkId/agents/:agentId/stream** - Stream agent responses (SSE)
   ```
   Response: Server-Sent Events stream
   Event format (includes agent context for multiplexing):
   data: {
     "agentId": "uuid",
     "agentType": "main",
     "agentName": "Main Orchestrator",
     "taskName": null,
     "type": "message",
     "data": {
       "content": "I'll help you..."
     },
     "timestamp": "2025-12-21T10:00:00Z"
   }
   data: {
     "agentId": "uuid2",
     "agentType": "implementation",
     "agentName": "Auth Fix",
     "taskName": "Implementing login flow",
     "type": "tool_use",
     "data": {
       "tool": "Write",
       "params": {...}
     },
     "timestamp": "2025-12-21T10:00:01Z"
   }
   data: {
     "agentId": "uuid2",
     "agentType": "implementation",
     "agentName": "Auth Fix",
     "taskName": "Implementing login flow",
     "type": "tool_result",
     "data": {
       "result": "..."
     },
     "timestamp": "2025-12-21T10:00:02Z"
   }
   data: {
     "agentId": "uuid",
     "agentType": "main",
     "agentName": "Main Orchestrator",
     "taskName": null,
     "type": "done",
     "data": null,
     "timestamp": "2025-12-21T10:00:03Z"
   }
   data: {
     "agentId": "uuid",
     "agentType": "main",
     "agentName": "Main Orchestrator",
     "taskName": null,
     "type": "error",
     "data": {
       "message": "..."
     },
     "timestamp": "2025-12-21T10:00:04Z"
   }
   ```
   **Sub-agent Streaming**: Main agent stream includes ALL network activity (multiplexed). When main agent spawns sub-agents (implementation, context collection, etc.), their activity appears in the main stream. Each event includes `agentId`, `agentType`, `agentName`, and `taskName` so the client can correctly attribute output and display agent-specific UI (e.g., collapsible sections per agent).

**Implementation note**: Endpoints run actual ClaudeClient instances. SSE streams real-time agent responses.
**Working directory behavior**:
- On `POST /networks`, call `startNew(initialMessage, workingDirectory: userRequestedDirectory)` which atomically creates the network with the working directory set. This is stored in `worktreePath` and persisted immediately.
- On `/messages` and `/stream`, load the network from persistence and call `resume(network)`. The persisted `worktreePath` is automatically used by all agents via `effectiveWorkingDirectory`.

#### 2.5 Implement Middleware
**New file**: `packages/vide_server/lib/middleware/cors_middleware.dart` (~40 lines)

**Responsibilities**:
- Add CORS headers (allow all origins for MVP - localhost only anyway)
- Handle preflight OPTIONS requests

#### 2.6 Implement Simple Permission System for MVP
**New file**: `packages/vide_server/lib/services/simple_permission_service.dart` (~80 lines)

**Purpose**: Simple auto-approve/deny permission rules for MVP

**Strategy**:
- Auto-approve safe read-only operations (Read, Grep, Glob, git status)
- Auto-approve Write/Edit to project directory only
- Auto-deny dangerous operations (Bash with rm/dd/mkfs, web requests to non-localhost)
- No user interaction needed

**Note**: For MVP testing on localhost. Post-MVP will add webhook callbacks.

#### 2.7 Implement DTOs (Data Transfer Objects)
**New file**: `packages/vide_server/lib/dto/network_dto.dart` (~150 lines)

**Purpose**: Request/response schemas

**Key DTOs**:
- `CreateNetworkRequest` - { initialMessage, workingDirectory (required) }
- `SendMessageRequest` - { content }
- `SSEEvent` - Enhanced for multiplexing:
  ```dart
  class SSEEvent {
    final String agentId;       // Which agent produced this event
    final String agentType;     // "main", "implementation", "planning", etc.
    final String? agentName;    // Human-readable name (e.g., "Auth Fix")
    final String? taskName;     // Current task (optional, set via MCP tool)
    final String type;          // "message", "tool_use", "tool_result", "done", "error"
    final dynamic data;         // Event-specific data (content, tool params, etc.)
    final DateTime timestamp;   // When this event occurred
  }
  ```
  This allows the REST client to correctly attribute events to agents and display agent-specific UI.

---

### Phase 2.8: Run Dart Analysis on REST Server
**Purpose**: Ensure vide_server compiles and has no errors before testing

**Steps**:
1. Run analysis on vide_server (from repo root):
   ```bash
   dart analyze packages/vide_server
   ```
2. Fix all errors and warnings by addressing root causes
3. Run analysis on all packages to ensure everything still works together (from repo root):
   ```bash
   dart analyze packages/vide_core
   dart analyze
   ```
4. Verify all three packages (vide_core, vide_server, vide_cli) are error-free before manual testing

**Note**: This checkpoint ensures the REST server is in a good state before we start integration testing. Root analysis_options.yaml applies to all packages.

---

### Phase 3: Testing & Polish (~1 hour)

#### 3.1 Manual Testing
**Test scenario**: End-to-end chat flow
1. Start server (from `packages/vide_server`): `dart run bin/vide_server.dart`
2. Create network (use printed URL): `curl -X POST http://127.0.0.1:<port>/api/v1/networks -d '{"initialMessage":"Hello","workingDirectory":"."}'`
3. Open SSE stream in browser or curl
4. Send message: `curl -X POST http://127.0.0.1:<port>/api/v1/networks/{id}/messages -d '{"content":"Write hello.dart"}'`
5. Watch agent response in SSE stream

#### 3.2 Documentation
**New files**:
- `packages/vide_server/README.md` - Server setup, configuration, deployment
- `packages/vide_server/API.md` - REST API documentation with examples
- Update root `README.md` - Explain dual-interface architecture

---

## Critical Files Summary

### Files to CREATE (16 new files, ~820 lines)

**packages/vide_core/** (7 files)
- `pubspec.yaml` - Core package definition (includes Riverpod)
- `lib/vide_core.dart` - Barrel export
- `lib/models/permission.dart` - PermissionRequest and PermissionResponse data classes extracted from TUI (40 lines)
- `lib/services/permission_provider.dart` - Permission abstraction interface (20 lines)
- `test/config_isolation_test.dart` - Verify config isolation
- `test/posthog_refactor_test.dart` - Verify PostHog refactor
- `test/provider_override_test.dart` - Verify provider overrides work

**packages/vide_server/** (8 files, ~750 lines total for MVP)
- `pubspec.yaml` - Server package definition
- `bin/vide_server.dart` - Server entry point (100 lines)
- `lib/routes/network_routes.dart` - 3 core endpoints with SSE (200 lines)
- `lib/middleware/cors_middleware.dart` - CORS headers (40 lines)
- `lib/services/simple_permission_service.dart` - Auto-approve/deny rules (80 lines)
- `lib/services/network_cache_manager.dart` - Hybrid caching for networks (40 lines)
- `lib/dto/network_dto.dart` - Request/response schemas including enhanced SSEEvent (150 lines)
- `lib/config/server_config.dart` - Port parsing and loopback binding rules (40 lines)

**vide_cli (root)** (1 file, TUI-specific)
- `lib/modules/permissions/permission_service_adapter.dart` - Adapter wrapping PermissionService to implement PermissionProvider interface (40 lines)

### Files to MOVE to vide_core (core non-TUI code; flutter_runtime_mcp stays)

**IMPORTANT**: Use `git mv` for ALL moves to preserve git history!

**Move from lib/ to packages/vide_core/** (ALL AS-IS, keeping Riverpod):

**Models:**
- `lib/modules/agent_network/models/*.dart` → `packages/vide_core/lib/models/`
- `lib/modules/memory/model/memory_entry.dart` → `packages/vide_core/lib/models/`

**Core Services:**
- `lib/modules/agent_network/service/agent_network_manager.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `lib/modules/agent_network/service/claude_manager.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `lib/modules/agent_network/service/agent_network_persistence_manager.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `lib/modules/agent_network/state/agent_status_manager.dart` → `packages/vide_core/lib/state/` (AS-IS)
- `lib/modules/memory/memory_service.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `lib/services/vide_config_manager.dart` → `packages/vide_core/lib/services/` (convert singleton → Riverpod provider)
- `lib/services/posthog_service.dart` → `packages/vide_core/lib/services/` (update init method)

**MCP Servers (entire directories):**
- `lib/modules/mcp/memory/` → `packages/vide_core/lib/mcp/memory/`
- `lib/modules/mcp/agent/` → `packages/vide_core/lib/mcp/agent/`
- `lib/modules/mcp/task_management/` → `packages/vide_core/lib/mcp/task_management/`
- `lib/modules/mcp/git/` → `packages/vide_core/lib/mcp/git/`
- `packages/flutter_runtime_mcp/` stays in place; add path dependency in `packages/vide_core/pubspec.yaml`

**Agent Configurations:**
- `lib/modules/agents/models/agent_configuration.dart` → `packages/vide_core/lib/agents/`
- `lib/modules/agents/configs/*.dart` → `packages/vide_core/lib/agents/`
- `lib/modules/agents/configs/prompt_sections/` → `packages/vide_core/lib/agents/prompt_sections/`

**Utilities:**
- `lib/utils/project_detector.dart` → `packages/vide_core/lib/utils/`
- `lib/utils/system_prompt_builder.dart` → `packages/vide_core/lib/utils/`
- `lib/utils/working_dir_provider.dart` → `packages/vide_core/lib/utils/`

### Files to UPDATE in vide_cli (root)

**vide_cli changes**:
- `pubspec.yaml` - Add vide_core dependency (path dependency)
- Update imports in ~30 files to use `package:vide_core/...`
- `bin/vide.dart` - Override providers in ProviderScope

**What STAYS in vide_cli:**
- TUI pages and components (`lib/modules/agent_network/pages/`, `lib/components/`) - all nocterm UI
- Permission Service (`lib/modules/permissions/`) - shows permission dialogs to user
- Sentry Service (`lib/services/sentry_service.dart`) - TUI-specific error reporting with nocterm integration
- Entry point (`bin/vide.dart`)

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│  Web Frontend (Future)                  │
│  React/Vue/Svelte                       │
└──────────────┬──────────────────────────┘
               │ HTTP/REST
┌──────────────▼──────────────────────────┐
│  vide_server (packages/vide_server)     │
│  ├─ REST API Endpoints (SSE streaming)  │
│  ├─ Simple Permission Service (MVP)     │
│  └─ Uses vide_core services             │
└──────────────┬──────────────────────────┘
               │
               │  Shares ALL business logic
               │
┌──────────────▼──────────────────────────┐
│  vide_core (packages/vide_core)         │
│  ├─ Models (AgentNetwork, etc.)         │
│  ├─ AgentNetworkManager (Riverpod)      │
│  ├─ ClaudeManager, AgentStatusManager   │
│  ├─ MemoryService, Persistence          │
│  ├─ MCP Servers (Memory, Agent,         │
│  │   TaskManagement, Git)               │
│  ├─ VideConfigManager, Agent Configs    │
│  └─ Depends on: flutter_runtime_mcp     │
│      (path dependency to sibling pkg)   │
└──────────────┬──────────────────────────┘
               │
               │  Used by TUI
               │
┌──────────────▼──────────────────────────┐
│  vide_cli (repo root - TUI)             │
│  ├─ TUI Pages & Components (nocterm)    │
│  ├─ Permission Service (dialog UI)      │
│  ├─ Entry point (bin/vide.dart)         │
│  └─ Depends on vide_core (path dep)     │
└─────────────────────────────────────────┘
```

---

## Implementation Sequence

### Phase 1: Foundation - Extract vide_core (Day 1-2) **CHECKPOINT PHASE**

**Pre-Investigation (COMPLETED)**:
- ✅ Confirmed nocterm_riverpod is safe to replace in vide_core (it's a wrapper with nocterm-specific BuildContext extensions)
- ✅ Explored permission system architecture (HTTP server + TUI dialogs, needs abstraction)
- ✅ Analyzed AgentNetworkManager (has built-in message queue, persistence via JSON, resume() flow)

**Implementation Steps** (Use `git mv` for ALL file moves!):
1. ✅ Create `packages/vide_core/` with pubspec.yaml (dependencies: claude_sdk via path, riverpod ^2.5.1, freezed, json_serializable, etc.)
2. ✅ **git mv** models to vide_core - AS-IS
3. ✅ **git mv** VideConfigManager to vide_core - convert singleton to Riverpod provider (add configRoot param)
4. ✅ **git mv** PostHogService to vide_core - update init method to accept VideConfigManager directly
5. ✅ **Extract** PermissionRequest and PermissionResponse from `lib/modules/permissions/permission_service.dart` to new `packages/vide_core/lib/models/permission.dart` (copy, not git mv - they're within a file), then **create** PermissionProvider abstract interface with Riverpod provider in `packages/vide_core/lib/services/permission_provider.dart`
6. ✅ **git mv** MemoryService to vide_core - AS-IS
7. ✅ **git mv** AgentNetworkPersistenceManager to vide_core - AS-IS
8. ✅ **git mv** all agent configs (and prompt_sections) to vide_core - AS-IS
9. ✅ **git mv** shared utilities (project_detector, system_prompt_builder, working_dir_provider) to vide_core
10. ✅ **git mv** AgentNetworkManager to vide_core - replace nocterm_riverpod with riverpod, update `startNew()` signature to add optional `workingDirectory` parameter (atomically sets `worktreePath` in network)
11. ✅ **git mv** MCP servers from `lib/modules/mcp` to vide_core - AS-IS; keep `flutter_runtime_mcp` in place with path dependency
12. ✅ **git mv** ClaudeManager and AgentStatusManager to vide_core - AS-IS
13. ✅ Update `pubspec.yaml` (root) to depend on vide_core (path dependency)
14. ✅ Update all imports in vide_cli to use `package:vide_core/...`
15. ✅ **RUN DART ANALYSIS**: `dart analyze packages/vide_core` then `dart analyze` - fix all errors/warnings at root cause (root analysis_options.yaml applies to all packages)
16. ✅ **Create** TUI permission adapter (wraps PermissionService to implement PermissionProvider)
17. ✅ **Add provider overrides in TUI**: Update `bin/vide.dart` to override VideConfigManager, permissionProvider, and workingDirProvider
18. ✅ **Add Refactoring Tests**: Create and run `config_isolation_test.dart`, `posthog_refactor_test.dart`, and `provider_override_test.dart` (tests must override providers in ProviderContainer)
19. ✅ **Test TUI still works - STOP HERE FOR CHECKPOINT**
20. ✅ Run full TUI test suite (from repo root): `dart test` - All 225 tests passing
21. ✅ Manually test: agent spawning, memory persistence, all MCP servers, Git operations, Flutter runtime
22. ✅ **Phase 1 COMPLETE - Ready to proceed to Phase 2**

### Phase 2: Build MVP REST Server (Day 3) **AFTER PHASE 1 CHECKPOINT**
23. ✅ Create `packages/vide_server/` with pubspec.yaml (dependencies: shelf, shelf_router, vide_core, riverpod)
24. ✅ Implement network cache manager (hybrid caching strategy)
25. ✅ Implement server entry point (bin/vide_server.dart) - create ProviderContainer with overrides
26. ✅ **Add provider overrides in REST**: VideConfigManager (configRoot = ~/.vide/api), permissionProvider (SimplePermissionService); workingDirProvider overridden to throw error (defensive programming - ensures workingDirectory always passed to startNew())
27. ✅ Implement CORS middleware (allow all origins for localhost MVP)
28. ✅ Implement simple permission service (auto-approve safe ops, deny dangerous ops) - implements PermissionProvider interface
29. ✅ Implement network DTOs (CreateNetworkRequest with mainAgentId in response, SendMessageRequest, WebSocketEvent)
30. ✅ Implement POST /api/v1/networks - calls `startNew(initialMessage, workingDirectory: userRequestedDirectory)`, returns mainAgentId for streaming
31. ✅ Implement POST /api/v1/networks/:id/messages - uses message queue (built-in to ClaudeClient)
32. ✅ Implement WebSocket streaming at /api/v1/networks/:id/agents/:agentId/stream - WebSocket streaming with multiplexed sub-agent activity (changed from SSE to WebSocket for better bidirectional support)
33. ✅ **RUN DART ANALYSIS**: `dart analyze packages/vide_server` then `dart analyze packages/vide_core` then `dart analyze` - fix all errors/warnings; verify all three packages are clean
34. ✅ **Test MVP end-to-end**: create network → get mainAgentId → open WebSocket stream → send message → watch agent responses
35. ✅ **Fix duplicate content bug**: Claude CLI sends both deltas and cumulative messages; fixed in `response.dart` and `conversation.dart`
36. ✅ **Add integration tests**: End-to-end test and duplicate content detection test in `packages/vide_server/test/integration/end_to_end_test.dart`
37. ⬜ **Verify TUI still works after Phase 2 changes** (pending manual verification)

### Phase 3: Testing & Documentation (Day 4)
38. Manual testing with curl and browser (full chat conversation workflow)
39. Add error handling for common cases (network errors, invalid requests)
40. Write API documentation with curl examples (packages/vide_server/API.md)
41. Create simple HTML test client for testing WebSocket streaming
42. Update root README.md to explain dual-interface architecture

---

## Key Architectural Decisions

### 1. Separate Processes
**Decision**: REST server runs as independent process from TUI
**Why**: Clean separation, independent deployment, no interference
**Trade-off**: Can't directly monitor server from TUI (acceptable for MVP)

### 2. NO Authentication for MVP
**Decision**: MVP has NO authentication - localhost testing only
**Why**: Focus on core functionality first, add security when deploying beyond localhost
**Trade-off**: Can't expose to internet (acceptable for MVP)

### 3. Session Isolation
**Decision**: Separate directories for TUI vs REST API
**Why**: Complete isolation, no conflicts between TUI and REST sessions
**Implementation**: `~/.vide/projects/` (TUI) vs `~/.vide/api/projects/` (REST)
**Trade-off**: Slight disk overhead (minimal impact)

### 4. Keep Riverpod in vide_core
**Decision**: vide_core includes Riverpod for state management
**Why**: Existing services already use Riverpod, REST API can use it too (it's not TUI-specific)
**Trade-off**: None - Riverpod is just a Dart package for dependency injection

### 5. Move All Non-TUI Code in Phase 1
**Decision**: Extract non-TUI code from `lib/` into packages/vide_core in one pass; keep standalone packages (like `flutter_runtime_mcp`) in `packages/`
**Why**: Goal is feature-for-feature equivalent web UI eventually
**Trade-off**: Bigger Phase 1, but avoids future refactoring pain

### 6. Use Riverpod Provider Overrides for UI-Specific Behavior
**Decision**: Inject UI-specific config via provider overrides instead of modifying core code
**Why**: Minimizes changes to Norbert's code - business logic moves AS-IS
**Examples**:
- VideConfigManager: TUI overrides with `configRoot = ~/.vide`, REST with `~/.vide/api`
- workingDirProvider: Each UI provides its own implementation
**Trade-off**: None - this is how Riverpod is meant to be used!

### 7. Loopback-Only Binding with Ephemeral Port (MVP)
**Decision**: Bind to loopback only and auto-select an unused port
**Why**: Prevents accidental exposure while auth is absent; no host config needed
**Trade-off**: Harder to front with a reverse proxy without changing config behavior

### 8. Permission Provider Abstraction
**Decision**: Create `PermissionProvider` interface in vide_core
**Why**: Allows business logic to request permissions without knowing implementation (TUI dialogs vs REST auto-rules)
**Implementation**:
- TUI: Adapter wraps existing HTTP server + dialog system
- REST: SimplePermissionService with auto-approve/deny rules
**Trade-off**: None - clean separation of concerns

### 9. Hybrid Network Caching
**Decision**: In-memory cache with persistence fallback
**Why**: Fast lookups (O(1)) while maintaining stateless server (can restart without losing networks)
**Implementation**: `NetworkCacheManager` checks cache first, loads from persistence if needed, caches result
**Trade-off**: Minimal - small memory overhead, but improves performance significantly

### 10. Multiplex Sub-Agent Activity
**Decision**: Main agent stream includes all sub-agent activity
**Why**: Client subscribes to one stream and sees complete network activity (main + implementation + context collection agents)
**Implementation**: Stream from main agent's ClaudeClient conversation feed
**Trade-off**: More complex stream parsing for client, but simpler subscription model

---

## Security Considerations (POST-MVP)

**Note**: MVP has NO authentication - localhost testing only!

When deploying beyond localhost (post-MVP):
1. **Passwords**: bcrypt hashing with salt (12 rounds)
2. **JWT/OAuth**: Access tokens (24h expiry), refresh tokens (30d expiry)
3. **Environment**: `VIDE_JWT_SECRET` environment variable (fail if not set)
4. **HTTPS**: Deploy with reverse proxy (Caddy/nginx)
5. **Input Validation**: Validate all request bodies, sanitize user input
6. **Rate Limiting**: Add to login endpoints to prevent brute force

---

## MVP Success Criteria

**Phase 1 - COMPLETE:**
✅ **TUI continues to work after refactoring to use vide_core**
✅ **Both TUI and REST API share the same business logic (single source of truth)**
✅ **All 225 tests passing**
✅ **dart analyze shows no issues**
✅ **TUI compiles and runs successfully**

**Phase 2 - IN PROGRESS:**
✅ **REST server starts on localhost (no auth - testing only)**
✅ **REST server auto-selects an unused port and prints the full URL**
✅ **Can create network with initial prompt via POST /api/v1/networks**
✅ **Can send messages via POST .../messages**
✅ **Can receive agent responses in real-time via WebSocket stream** (changed from SSE to WebSocket)
✅ **WebSocket streaming correctly handles deltas without duplicate content**
⬜ **Full chat conversation works end-to-end via REST API** (multi-turn test is flaky)
⬜ **Agent can spawn sub-agents (implementation, context collection, etc.)** (not yet tested)
✅ **Permissions auto-approve safe operations, deny dangerous ones**
✅ **Bug fixes in vide_core automatically benefit both TUI and REST API** (duplicate content fix in claude_sdk benefits both)

---

## Post-MVP Enhancements

### Phase 4: Add Security (when deploying beyond localhost)
- JWT/OAuth authentication
- User accounts and registration
- API keys for server-to-server
- Rate limiting on endpoints

### Phase 5: Advanced Features
- Webhook permission callbacks (replace simple auto-approve/deny)
- WebSocket support (alternative to SSE)
- Multi-client real-time session sharing
  - Allow same user to access sessions from multiple devices (desktop, phone, etc.)
  - Real-time synchronization of agent network state across all logged-in clients
  - Live updates propagated to all connected clients via SSE/WebSocket
  - Shared session state maintained on server
- Additional REST endpoints:
  - GET /networks (list all networks)
  - GET /networks/:id (get network details)
  - DELETE /networks/:id (delete network)
  - GET /networks/:id/status (get current status without streaming)
  - GET /networks/:id/agents (list agents in network)

### Phase 6: Production Readiness
- PostgreSQL/SQLite (replace file-based storage)
- Shared sessions between TUI and REST (optional)
- Multi-project workspaces
- Comprehensive test suite
- Deployment documentation
