# REST API Architecture Plan for Vide CLI

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
- **Workspace dependencies**: Use workspace resolution for flutter_runtime_mcp
- **nocterm_riverpod**: Confirmed safe to replace in vide_core (just a wrapper with TUI-specific extensions)

## Architecture Strategy

### Package Structure
Create shared core package and refactor both CLI and server to use it:

```
apps/
├── vide_cli/              # MOVED: TUI app
└── (future vide_flutter)

packages/
├── vide_core/             # NEW: Shared business logic (models, services)
├── vide_server/           # NEW: REST API server
├── flutter_runtime_mcp/   # EXISTING: stays here
└── (other internal packages)
```

**Workspace note**: Repo root becomes workspace tooling only (build/test scripts, docs); add a root `pubspec.yaml` with explicit lists for both apps and packages in `workspace` (apps: `apps/vide_cli`; packages: `packages/vide_core`, `packages/vide_server`, `packages/flutter_runtime_mcp`) and set `resolution: workspace` in each app/package `pubspec.yaml`. Update `just` scripts to point at `apps/vide_cli`.

**Rationale**: Single source of truth for business logic. Both TUI and REST API depend on vide_core. Bug fixes and features benefit both implementations immediately.

**Key principle**: DRY (Don't Repeat Yourself). Shared code lives in vide_core, UI-specific code stays in each package.

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

#### 1.0 Prepare Workspace
- Move `vide_cli` into `apps/vide_cli`
- Add/Update root `pubspec.yaml` with explicit `workspace` lists for apps and packages
- Set `resolution: workspace` in `apps/vide_cli/pubspec.yaml`, `packages/vide_core/pubspec.yaml`, `packages/vide_server/pubspec.yaml`, and `packages/flutter_runtime_mcp/pubspec.yaml`
- Update `just` scripts to point at `apps/vide_cli`

#### 1.1 Create `packages/vide_core/` Package
**New Files:**
- `packages/vide_core/pubspec.yaml`
- `packages/vide_core/lib/vide_core.dart` (barrel export)

**Dependencies**: Core Dart packages + Riverpod ^3.0.3 only (replace `nocterm_riverpod` imports with `riverpod` when moving files to vide_core)

#### 1.2 Move Models to `vide_core`
**Move these files** from `apps/vide_cli/lib/` to `packages/vide_core/lib/models/`:
- `apps/vide_cli/lib/modules/agent_network/models/agent_network.dart` → `packages/vide_core/lib/models/agent_network.dart`
- `apps/vide_cli/lib/modules/agent_network/models/agent_metadata.dart` → `packages/vide_core/lib/models/agent_metadata.dart`
- `apps/vide_cli/lib/modules/agent_network/models/agent_id.dart` → `packages/vide_core/lib/models/agent_id.dart`
- `apps/vide_cli/lib/modules/memory/model/memory_entry.dart` → `packages/vide_core/lib/models/memory_entry.dart`

**Changes required**: None to the models themselves - they're already pure data classes with freezed.

#### 1.3 Move MemoryService to `vide_core`
**Move file**: `apps/vide_cli/lib/modules/memory/memory_service.dart` → `packages/vide_core/lib/services/memory_service.dart`

**Changes required**: None - move AS-IS including the Riverpod provider

#### 1.4 Move VideConfigManager to `vide_core`
**Move file**: `apps/vide_cli/lib/services/vide_config_manager.dart` → `packages/vide_core/lib/services/vide_config_manager.dart`

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
**Move file**: `apps/vide_cli/lib/services/posthog_service.dart` → `packages/vide_core/lib/services/posthog_service.dart`

**Changes**:
- Update `init()` to accept `Ref` parameter and use `ref.read(videConfigManagerProvider)` to access config (instead of singleton)
- This allows PostHogService to use dependency injection via Riverpod providers

#### 1.6 Create Permission Provider Abstraction
**New file**: `packages/vide_core/lib/services/permission_provider.dart` (~60 lines)

**Purpose**: Create an abstraction for permission requests that works for both TUI (dialogs) and REST (auto-approve rules)

**Key Classes**:
- `PermissionRequest` - Tool invocation request data
- `PermissionDecision` - Allow/deny decision with optional reason
- `PermissionProvider` - Abstract interface for permission handling
- `permissionProvider` - Riverpod provider (must be overridden by UI)

**Implementation Strategy**:
- TUI: Create adapter that wraps existing `PermissionService` HTTP server + dialog UI
- REST: Create `SimplePermissionService` with auto-approve/deny rules

**Rationale**: Allows vide_core to request permissions without knowing how they're granted. Each UI implements the provider differently.

#### 1.7 Move AgentNetworkPersistenceManager to `vide_core`
**Move file**: `apps/vide_cli/lib/modules/agent_network/service/agent_network_persistence_manager.dart` → `packages/vide_core/lib/services/agent_network_persistence_manager.dart`

**Changes**: None - move AS-IS including the Riverpod provider

#### 1.8 Move Agent Configurations to `vide_core`
**Move files** from `apps/vide_cli/lib/modules/agents/` to `packages/vide_core/lib/agents/`:
- `models/agent_configuration.dart` → `packages/vide_core/lib/agents/agent_configuration.dart`
- `configs/main_agent_config.dart` → `packages/vide_core/lib/agents/main_agent_config.dart`
- `configs/implementation_agent_config.dart` → `packages/vide_core/lib/agents/implementation_agent_config.dart`
- `configs/context_collection_agent_config.dart` → `packages/vide_core/lib/agents/context_collection_agent_config.dart`
- `configs/planning_agent_config.dart` → `packages/vide_core/lib/agents/planning_agent_config.dart`
- `configs/flutter_tester_agent_config.dart` → `packages/vide_core/lib/agents/flutter_tester_agent_config.dart`
- **Recursive Move**: `configs/prompt_sections/` → `packages/vide_core/lib/agents/prompt_sections/` (ALL contents)

**Changes**: Remove any nocterm-specific imports. These are pure data classes.

#### 1.9 Move Shared Utilities to `vide_core`
**Move these files** from `apps/vide_cli/lib/utils/` to `packages/vide_core/lib/utils/`:
- `project_detector.dart`
- `system_prompt_builder.dart`
- `working_dir_provider.dart`

**Changes**: Update imports in files that use these.

#### 1.10 Move AgentNetworkManager to `vide_core`
**Move file**: `apps/vide_cli/lib/modules/agent_network/service/agent_network_manager.dart` → `packages/vide_core/lib/services/agent_network_manager.dart`

**Changes**:
- Replace `package:nocterm_riverpod/nocterm_riverpod.dart` with `package:riverpod/riverpod.dart`
- Move AS-IS including all Riverpod code!

**workingDirProvider handling**:
- Provider definition moved in step 1.8
- TUI overrides with its working directory
- REST overrides only when creating a network; resume uses persisted `worktreePath`

**Rationale**: Zero changes to AgentNetworkManager logic! UI-specific behavior injected via provider overrides.

**Note**: nocterm_riverpod is safe to replace - it's a wrapper that adds nocterm-specific BuildContext extensions. The core Riverpod features (Provider, StateNotifierProvider, ProviderContainer) are identical to standard riverpod.

#### 1.11 Move MCP Servers to vide_core (keep flutter_runtime_mcp)
**Move files**:
- `apps/vide_cli/lib/modules/mcp/memory/` → `packages/vide_core/lib/mcp/memory/` (entire directory)
- `apps/vide_cli/lib/modules/mcp/agent/` → `packages/vide_core/lib/mcp/agent/` (entire directory)
- `apps/vide_cli/lib/modules/mcp/task_management/` → `packages/vide_core/lib/mcp/task_management/` (entire directory)
- `apps/vide_cli/lib/modules/mcp/git/` → `packages/vide_core/lib/mcp/git/` (entire directory)
- `packages/flutter_runtime_mcp/` stays in place; add workspace dependency in `packages/vide_core/pubspec.yaml`

**Changes**: Move MCP servers AS-IS; add `flutter_runtime_mcp: ^0.1.0` with workspace resolution in vide_core.

**Rationale**: Centralize non-TUI MCP logic in vide_core while keeping `flutter_runtime_mcp` as a sibling package. Goal is feature-for-feature equivalent web UI eventually.

#### 1.12 Move ClaudeManager and AgentStatusManager to vide_core
**Move files**:
- `apps/vide_cli/lib/modules/agent_network/service/claude_manager.dart` → `packages/vide_core/lib/services/claude_manager.dart`
- `apps/vide_cli/lib/modules/agent_network/state/agent_status_manager.dart` → `packages/vide_core/lib/state/agent_status_manager.dart`

**Changes**: None - move AS-IS including Riverpod providers

**Rationale**: These are core orchestration services used by AgentNetworkManager. Need them in vide_core for the REST API.

#### 1.13 Update vide_cli to use vide_core
**Modify**: `apps/vide_cli/pubspec.yaml` - Add dependency (workspace resolution):
```yaml
dependencies:
  vide_core: ^0.1.0
```

**Update imports** in all files that used moved code:
- Replace `package:vide_cli/modules/agent_network/models/...` with `package:vide_core/models/...`
- Replace `package:vide_cli/modules/agent_network/service/...` with `package:vide_core/services/...`
- Replace `package:vide_cli/modules/mcp/...` with `package:vide_core/mcp/...`
- Replace `package:vide_cli/services/vide_config_manager.dart` with `package:vide_core/services/vide_config_manager.dart`
- Etc.

**Create TUI Permission Adapter**:
- Create `apps/vide_cli/lib/modules/permissions/permission_service_adapter.dart`
- Implement `PermissionProvider` interface by wrapping existing `PermissionService`
- This adapter converts between vide_core's `PermissionRequest` and TUI's permission dialog system

**Update TUI Entry Point**:
- Modify `apps/vide_cli/bin/vide.dart`:
  - Initialize the `ProviderScope` with overrides:
    ```dart
    ProviderScope(
      overrides: [
        videConfigManagerProvider.overrideWithValue(VideConfigManager(configRoot: '~/.vide')),
        permissionProvider.overrideWithValue(TUIPermissionProvider(permissionService)),
        // workingDirProvider is likely overridden here or in a scope closer to execution
      ],
      child: VideApp(),
    )
    ```

#### 1.14 Add Refactoring Verification Tests
**Purpose**: Ensure the new `vide_core` abstraction and dependency injection work correctly.

**New Tests in `packages/vide_core/test/`**:
- `test/config_isolation_test.dart`: Verify that `VideConfigManager` respects the injected `configRoot` path.
- `test/posthog_refactor_test.dart`: Verify that `PostHogService` initializes correctly with a provided config path (no singleton usage).
- `test/provider_override_test.dart`: Basic test to verify that `videConfigManagerProvider` throws `UnimplementedError` if not overridden, and works if overridden.

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
  vide_core: ^0.1.0
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
- Create ProviderContainer with overrides
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
   Event format:
   data: {"type":"message","content":"I'll help you..."}
   data: {"type":"tool_use","tool":"Write","params":{...}}
   data: {"type":"tool_result","result":"..."}
   data: {"type":"done"}
   data: {"type":"error","message":"..."}
   ```
   **Sub-agent Streaming**: Main agent stream includes ALL network activity (multiplexed). When main agent spawns sub-agents (implementation, context collection, etc.), their activity appears in the main stream. Client subscribes to one stream and sees complete network activity.

**Implementation note**: Endpoints run actual ClaudeClient instances. SSE streams real-time agent responses.
**Working directory behavior**:
- On `POST /networks`, override `workingDirProvider` with `workingDirectory`, then call `setWorktreePath(workingDirectory)` so it persists in `AgentNetwork.worktreePath`.
- On `/messages` and `/stream`, load the network from persistence, call `resume(network)`, and rely on `worktreePath` for the effective working directory.

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
**New file**: `packages/vide_server/lib/dto/network_dto.dart` (~100 lines)

**Purpose**: Request/response schemas

**Key DTOs**:
- `CreateNetworkRequest` - { initialMessage, workingDirectory (required) }
- `SendMessageRequest` - { content }
- `SSEEvent` - { type, data }

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

### Files to CREATE (~12 new files, ~700 lines)

**workspace root**
- `pubspec.yaml` - Workspace config (`publish_to: none`, `workspace: [apps/vide_cli, packages/vide_core, packages/vide_server, packages/flutter_runtime_mcp]`)

**packages/vide_core/**
- `pubspec.yaml` - Core package definition (includes Riverpod)
- `lib/vide_core.dart` - Barrel export
- `lib/services/permission_provider.dart` - Permission abstraction interface (60 lines)
- `test/config_isolation_test.dart`
- `test/posthog_refactor_test.dart`
- `test/provider_override_test.dart`

**packages/vide_server/** (~700 lines total for MVP)
- `pubspec.yaml` - Server package definition
- `bin/vide_server.dart` - Server entry point (100 lines)
- `lib/routes/network_routes.dart` - 3 core endpoints with SSE (200 lines)
- `lib/middleware/cors_middleware.dart` - CORS headers (40 lines)
- `lib/services/simple_permission_service.dart` - Auto-approve/deny rules (80 lines)
- `lib/services/network_cache_manager.dart` - Hybrid caching for networks (40 lines)
- `lib/dto/network_dto.dart` - Request/response schemas (100 lines)
- `lib/config/server_config.dart` - Port parsing and loopback binding rules (40 lines)

**apps/vide_cli/** (TUI-specific)
- `lib/modules/permissions/permission_service_adapter.dart` - Adapter wrapping PermissionService to implement PermissionProvider interface (40 lines)

### Files to MOVE to vide_core (core non-TUI code; flutter_runtime_mcp stays)

**Move from apps/vide_cli/lib/ to packages/vide_core/** (ALL AS-IS, keeping Riverpod):

**Models:**
- `apps/vide_cli/lib/modules/agent_network/models/*.dart` → `packages/vide_core/lib/models/`
- `apps/vide_cli/lib/modules/memory/model/memory_entry.dart` → `packages/vide_core/lib/models/`

**Core Services:**
- `apps/vide_cli/lib/modules/agent_network/service/agent_network_manager.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `apps/vide_cli/lib/modules/agent_network/service/claude_manager.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `apps/vide_cli/lib/modules/agent_network/service/agent_network_persistence_manager.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `apps/vide_cli/lib/modules/agent_network/state/agent_status_manager.dart` → `packages/vide_core/lib/state/` (AS-IS)
- `apps/vide_cli/lib/modules/memory/memory_service.dart` → `packages/vide_core/lib/services/` (AS-IS)
- `apps/vide_cli/lib/services/vide_config_manager.dart` → `packages/vide_core/lib/services/` (convert singleton → Riverpod provider)
- `apps/vide_cli/lib/services/posthog_service.dart` → `packages/vide_core/lib/services/` (update init method)

**MCP Servers (entire directories):**
- `apps/vide_cli/lib/modules/mcp/memory/` → `packages/vide_core/lib/mcp/memory/`
- `apps/vide_cli/lib/modules/mcp/agent/` → `packages/vide_core/lib/mcp/agent/`
- `apps/vide_cli/lib/modules/mcp/task_management/` → `packages/vide_core/lib/mcp/task_management/`
- `apps/vide_cli/lib/modules/mcp/git/` → `packages/vide_core/lib/mcp/git/`
- `packages/flutter_runtime_mcp/` stays in place; add `flutter_runtime_mcp: ^0.1.0` in `packages/vide_core/pubspec.yaml`

**Agent Configurations:**
- `apps/vide_cli/lib/modules/agents/models/agent_configuration.dart` → `packages/vide_core/lib/agents/`
- `apps/vide_cli/lib/modules/agents/configs/*.dart` → `packages/vide_core/lib/agents/`
- `apps/vide_cli/lib/modules/agents/configs/prompt_sections/` → `packages/vide_core/lib/agents/prompt_sections/`

**Utilities:**
- `apps/vide_cli/lib/utils/project_detector.dart` → `packages/vide_core/lib/utils/`
- `apps/vide_cli/lib/utils/system_prompt_builder.dart` → `packages/vide_core/lib/utils/`
- `apps/vide_cli/lib/utils/working_dir_provider.dart` → `packages/vide_core/lib/utils/`

### Files to UPDATE in vide_cli (apps/vide_cli)

**vide_cli changes**:
- `apps/vide_cli/pubspec.yaml` - Add vide_core dependency (workspace resolution)
- Update imports in ~30 files to use `package:vide_core/...`
- `apps/vide_cli/bin/vide.dart` - Override providers in ProviderScope

**What STAYS in vide_cli:**
- TUI pages and components (`apps/vide_cli/lib/modules/agent_network/pages/`, `apps/vide_cli/lib/components/`) - all nocterm UI
- Permission Service (`apps/vide_cli/lib/modules/permissions/`) - shows permission dialogs to user
- Entry point (`apps/vide_cli/bin/vide.dart`)

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│  Web Frontend (Future)                  │
│  React/Vue/Svelte                       │
└──────────────┬──────────────────────────┘
               │ HTTP/REST
┌──────────────▼──────────────────────────┐
│  vide_server (NEW)                      │
│  ├─ REST API Endpoints (SSE streaming)  │
│  ├─ Simple Permission Service (MVP)     │
│  └─ Uses vide_core services             │
└──────────────┬──────────────────────────┘
               │
               │  Shares ALL business logic
               │
┌──────────────▼──────────────────────────┐
│  vide_core (NEW - Extracted)            │
│  ├─ Models (AgentNetwork, etc.)         │
│  ├─ AgentNetworkManager (Riverpod)      │
│  ├─ ClaudeManager, AgentStatusManager   │
│  ├─ MemoryService, Persistence          │
│  ├─ ALL MCP Servers (Memory, Agent,     │
│  │   TaskManagement, Git, Flutter)      │
│  └─ VideConfigManager, Agent Configs    │
└──────────────┬──────────────────────────┘
               │
               │  Used by TUI
               │
┌──────────────▼──────────────────────────┐
│  vide_cli (apps/ - TUI only)            │
│  ├─ TUI Pages & Components (nocterm)    │
│  ├─ Permission Service (dialog UI)      │
│  ├─ Entry point (apps/vide_cli/bin/vide.dart) │
│  └─ Depends on vide_core                │
└─────────────────────────────────────────┘
```

---

## Implementation Sequence

### Phase 1: Foundation - Extract vide_core (Day 1-2) **CHECKPOINT PHASE**

**Pre-Investigation (COMPLETED)**:
- ✅ Confirmed nocterm_riverpod is safe to replace in vide_core (it's a wrapper with nocterm-specific BuildContext extensions)
- ✅ Explored permission system architecture (HTTP server + TUI dialogs, needs abstraction)
- ✅ Analyzed AgentNetworkManager (has built-in message queue, persistence via JSON, resume() flow)

**Implementation Steps**:
0. Move `vide_cli` into `apps/vide_cli`, add workspace root `pubspec.yaml` with explicit app/package `workspace` lists, set `resolution: workspace` in all app/package pubspecs, and update `just` scripts
1. Create `packages/vide_core/` with pubspec.yaml (dependencies: claude_api, riverpod ^3.0.3, freezed, json_serializable, etc.)
2. **Move** models to vide_core - AS-IS
3. **Move** VideConfigManager to vide_core - convert singleton to Riverpod provider (add configRoot param)
4. **Move** PostHogService to vide_core - update init method to use ref.read(videConfigManagerProvider)
5. **Create** permission provider abstraction (PermissionProvider interface)
6. **Move** MemoryService to vide_core - AS-IS
7. **Move** AgentNetworkPersistenceManager to vide_core - AS-IS
8. **Move** all agent configs (and prompt_sections) to vide_core - AS-IS
9. **Move** shared utilities (project_detector, system_prompt_builder, working_dir_provider) to vide_core
10. **Move** AgentNetworkManager to vide_core - AS-IS (replace nocterm_riverpod with riverpod)
11. **Move** MCP servers from `apps/vide_cli/lib/modules/mcp` to vide_core - AS-IS; keep `flutter_runtime_mcp` in place with workspace dependency
12. **Move** ClaudeManager and AgentStatusManager to vide_core - AS-IS
13. Update `apps/vide_cli/pubspec.yaml` to depend on vide_core (workspace resolution)
14. Update all imports in vide_cli
15. **Create** TUI permission adapter (wraps PermissionService to implement PermissionProvider)
16. **Add provider overrides in TUI**: Update `bin/vide.dart` to override VideConfigManager, permissionProvider, and workingDirProvider
17. **Add Refactoring Tests**: Create and run `config_isolation_test.dart`, `posthog_refactor_test.dart`, and `provider_override_test.dart`
18. **Test TUI still works - STOP HERE FOR CHECKPOINT**
19. Run full TUI test suite (from `apps/vide_cli`): `dart test`
20. Manually test: agent spawning, memory persistence, all MCP servers, Git operations, Flutter runtime
21. **Only proceed to Phase 2 after TUI is 100% verified working**

### Phase 2: Build MVP REST Server (Day 3) **AFTER PHASE 1 CHECKPOINT**
22. Create `packages/vide_server/` with pubspec.yaml (dependencies: shelf, shelf_router, vide_core, riverpod)
23. Implement network cache manager (hybrid caching strategy)
24. Implement server entry point (bin/vide_server.dart) - create ProviderContainer with overrides
25. **Add provider overrides in REST**: VideConfigManager (configRoot = ~/.vide/api), permissionProvider (SimplePermissionService); override workingDirProvider only when starting a new network
26. Implement CORS middleware (allow all origins for localhost MVP)
27. Implement simple permission service (auto-approve safe ops, deny dangerous ops) - implements PermissionProvider interface
28. Implement network DTOs (CreateNetworkRequest with mainAgentId in response, SendMessageRequest, SSEEvent)
29. Implement POST /api/v1/networks - uses AgentNetworkManager from vide_core, returns mainAgentId for streaming
30. Implement POST /api/v1/networks/:id/messages - uses message queue (built-in to ClaudeClient)
31. Implement GET /api/v1/networks/:id/agents/:agentId/stream - SSE streaming with multiplexed sub-agent activity
32. **Test MVP end-to-end**: create network → get mainAgentId → open stream → send message → watch agent + sub-agent responses
33. **Verify TUI still works after Phase 2 changes**

### Phase 3: Testing & Documentation (Day 4)
34. Manual testing with curl and browser (full chat conversation workflow)
35. Add error handling for common cases (network errors, invalid requests)
36. Write API documentation with curl examples (packages/vide_server/API.md)
37. Create simple HTML test client for testing SSE streaming
38. Update root README.md to explain dual-interface architecture

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

### 5. Move All Non-TUI `apps/vide_cli/lib/` Code in Phase 1
**Decision**: Move non-TUI code from `apps/vide_cli/lib/` into vide_core in one pass; keep standalone packages (like `flutter_runtime_mcp`) in `packages/`
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

✅ **TUI continues to work after refactoring to use vide_core**
✅ **Both TUI and REST API share the same business logic (single source of truth)**
✅ **REST server starts on localhost (no auth - testing only)**
✅ **REST server auto-selects an unused port and prints the full URL**
✅ **Can create network with initial prompt via POST /api/v1/networks**
✅ **Can send messages via POST .../messages**
✅ **Can receive agent responses in real-time via SSE stream**
✅ **Full chat conversation works end-to-end via REST API**
✅ **Agent can spawn sub-agents (implementation, context collection, etc.)**
✅ **Permissions auto-approve safe operations, deny dangerous ones**
✅ **Bug fixes in vide_core automatically benefit both TUI and REST API**

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
- Additional REST endpoints:
  - GET /networks (list all networks)
  - GET /networks/:id (get network details)
  - DELETE /networks/:id (delete network)
  - GET /networks/:id (delete network)
  - GET /networks/:id/agents (list agents in network)

### Phase 6: Production Readiness
- PostgreSQL/SQLite (replace file-based storage)
- Shared sessions between TUI and REST (optional)
- Multi-project workspaces
- Comprehensive test suite
- Deployment documentation
