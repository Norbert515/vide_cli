# REST API Architecture Plan for Vide CLI

## Overview
Transform Vide CLI from a pure TUI application into a dual-interface architecture supporting both CLI (text UI) and Web (REST API backend). The REST API server will run as a separate process, exposing core functionality via HTTP endpoints for building a web frontend.

## User Requirements
- **Architecture**: Separate processes - REST API server runs independently from TUI
- **Security**: None for MVP (localhost testing only) - add authentication post-MVP
- **Sessions**: Separate agent network sessions - REST and TUI don't share state
- **Scope**: Minimal MVP - Start session with prompt, get agent response via SSE streaming

## Architecture Strategy

### Package Structure
Create shared core package and refactor both CLI and server to use it:

```
packages/
├── vide_core/          # NEW: Shared business logic (models, services)
├── vide_server/        # NEW: REST API server
└── (vide_cli moves to packages/vide_cli)
```

**Rationale**: Single source of truth for business logic. Both TUI and REST API depend on vide_core. Bug fixes and features benefit both implementations immediately.

**Key principle**: DRY (Don't Repeat Yourself). Shared code lives in vide_core, UI-specific code stays in each package.

### Session Isolation Strategy
Use user-scoped persistence directories to completely isolate REST and TUI sessions:

```
TUI:  ~/.vide/projects/{encoded-path}/
REST: ~/.vide/api/projects/{encoded-path}/
```

**Note**: No user isolation for MVP since there's no authentication. Post-MVP will add user-scoped directories.

This prevents any conflicts between CLI and web users working on the same project.

## Implementation Plan

### Phase 1: Extract Core Business Logic (~3-4 hours)

#### 1.1 Create `packages/vide_core/` Package
**New Files:**
- `packages/vide_core/pubspec.yaml`
- `packages/vide_core/lib/vide_core.dart` (barrel export)

**Dependencies**: Core Dart packages + Riverpod (no nocterm - that's TUI-specific)

#### 1.2 Move Models to `vide_core`
**Move these files** from `lib/` to `packages/vide_core/lib/models/`:
- `lib/modules/agent_network/models/agent_network.dart` → `packages/vide_core/lib/models/agent_network.dart`
- `lib/modules/agent_network/models/agent_metadata.dart` → `packages/vide_core/lib/models/agent_metadata.dart`
- `lib/modules/agent_network/models/agent_id.dart` → `packages/vide_core/lib/models/agent_id.dart`
- `lib/modules/memory/model/memory_entry.dart` → `packages/vide_core/lib/models/memory_entry.dart`

**Changes required**: None to the models themselves - they're already pure data classes with freezed.

#### 1.3 Move MemoryService to `vide_core`
**Move file**: `lib/modules/memory/memory_service.dart` → `packages/vide_core/lib/services/memory_service.dart`

**Changes required**: None - move AS-IS including the Riverpod provider

#### 1.4 Move VideConfigManager to `vide_core`
**Move file**: `lib/services/vide_config_manager.dart` → `packages/vide_core/lib/services/vide_config_manager.dart`

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

#### 1.5 Move AgentNetworkPersistenceManager to `vide_core`
**Move file**: `lib/modules/agent_network/service/agent_network_persistence_manager.dart` → `packages/vide_core/lib/services/agent_network_persistence_manager.dart`

**Changes**: None - move AS-IS including the Riverpod provider

#### 1.6 Move Agent Configurations to `vide_core`
**Move files** from `lib/modules/agents/` to `packages/vide_core/lib/agents/`:
- `models/agent_configuration.dart` → `packages/vide_core/lib/agents/agent_configuration.dart`
- `configs/main_agent_config.dart` → `packages/vide_core/lib/agents/main_agent_config.dart`
- `configs/implementation_agent_config.dart` → `packages/vide_core/lib/agents/implementation_agent_config.dart`
- `configs/context_collection_agent_config.dart` → `packages/vide_core/lib/agents/context_collection_agent_config.dart`
- `configs/planning_agent_config.dart` → `packages/vide_core/lib/agents/planning_agent_config.dart`
- `configs/flutter_tester_agent_config.dart` → `packages/vide_core/lib/agents/flutter_tester_agent_config.dart`

**Changes**: Remove any nocterm-specific imports. These are pure data classes.

#### 1.7 Move AgentNetworkManager to `vide_core`
**Move file**: `lib/modules/agent_network/service/agent_network_manager.dart` → `packages/vide_core/lib/services/agent_network_manager.dart`

**Changes**: NONE - move AS-IS including all Riverpod code!

**workingDirProvider handling**:
- Provider already exists and reads from `workingDirProvider`
- Move `workingDirProvider` definition to vide_core
- TUI overrides with its working directory
- REST overrides with request-specific working directory

**Rationale**: Zero changes to AgentNetworkManager! UI-specific behavior injected via provider overrides.

#### 1.8 Move ALL MCP Servers to vide_core
**Move files**:
- `lib/modules/mcp/memory/` → `packages/vide_core/lib/mcp/memory/` (entire directory)
- `lib/modules/mcp/agent/` → `packages/vide_core/lib/mcp/agent/` (entire directory)
- `lib/modules/mcp/task_management/` → `packages/vide_core/lib/mcp/task_management/` (entire directory)
- `lib/modules/mcp/git/` → `packages/vide_core/lib/mcp/git/` (entire directory)
- `packages/flutter_runtime_mcp/` → `packages/vide_core/packages/flutter_runtime_mcp/` (entire package)

**Changes**: None - move AS-IS including any Riverpod providers

**Rationale**: Moving EVERYTHING non-TUI now avoids future refactoring. Goal is feature-for-feature equivalent web UI eventually.

#### 1.9 Move ClaudeManager and AgentStatusManager to vide_core
**Move files**:
- `lib/modules/agent_network/service/claude_manager.dart` → `packages/vide_core/lib/services/claude_manager.dart`
- `lib/modules/agent_network/state/agent_status_manager.dart` → `packages/vide_core/lib/state/agent_status_manager.dart`

**Changes**: None - move AS-IS including Riverpod providers

**Rationale**: These are core orchestration services used by AgentNetworkManager. Need them in vide_core for the REST API.

#### 1.10 Update vide_cli to use vide_core
**Modify**: `pubspec.yaml` - Add dependency:
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

**No provider changes needed** - providers moved with their services

---

### Phase 2: Build REST API Server (~2-3 hours) **AFTER PHASE 1 CHECKPOINT**

#### 2.1 Create `packages/vide_server/` Package
**New file**: `packages/vide_server/pubspec.yaml`

**Dependencies**:
```yaml
dependencies:
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  vide_core:
    path: ../vide_core
```

**Note**: No JWT, bcrypt, or auth dependencies for MVP!

#### 2.2 Implement Server Entry Point
**New file**: `packages/vide_server/bin/vide_server.dart` (~100 lines)

**Responsibilities**:
- Parse CLI arguments (port, host)
- Initialize VideConfigManager
- Create shelf HTTP server
- Set up middleware pipeline (CORS, logging only - no auth!)
- Mount routes
- Handle graceful shutdown

**Entry point**:
```dart
void main(List<String> args) async {
  final config = parseServerConfig(args);  // Just port and host
  VideConfigManager().initialize();

  final handler = createHandler();
  final server = await serve(handler, config.host, config.port);

  print('Vide API Server: http://${server.address.host}:${server.port}');
  print('WARNING: No authentication - localhost only!');
}
```

#### 2.3 Implement Core Network API Endpoints (MVP)
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

2. **POST /api/v1/networks/:networkId/messages** - Send message to agent
   ```
   Request:  {"content": "Now make it print goodbye too"}
   Response: {"status": "sent"}
   ```

3. **GET /api/v1/networks/:networkId/agents/:agentId/stream** - Stream agent responses (SSE)
   ```
   Response: Server-Sent Events stream
   Event format:
   data: {"type":"message","content":"I'll help you..."}
   data: {"type":"tool_use","tool":"Write","params":{...}}
   data: {"type":"tool_result","result":"..."}
   ```

**Implementation note**: Endpoints run actual ClaudeClient instances. SSE streams real-time agent responses.

#### 2.4 Implement Middleware
**New file**: `packages/vide_server/lib/middleware/cors_middleware.dart` (~40 lines)

**Responsibilities**:
- Add CORS headers (allow all origins for MVP - localhost only anyway)
- Handle preflight OPTIONS requests

#### 2.5 Implement Simple Permission System for MVP
**New file**: `packages/vide_server/lib/services/simple_permission_service.dart` (~80 lines)

**Purpose**: Simple auto-approve/deny permission rules for MVP

**Strategy**:
- Auto-approve safe read-only operations (Read, Grep, Glob, git status)
- Auto-approve Write/Edit to project directory only
- Auto-deny dangerous operations (Bash with rm/dd/mkfs, web requests to non-localhost)
- No user interaction needed

**Note**: For MVP testing on localhost. Post-MVP will add webhook callbacks.

#### 2.6 Implement DTOs (Data Transfer Objects)
**New file**: `packages/vide_server/lib/dto/network_dto.dart` (~100 lines)

**Purpose**: Request/response schemas

**Key DTOs**:
- `CreateNetworkRequest` - { initialMessage, workingDirectory }
- `SendMessageRequest` - { content }
- `SSEEvent` - { type, data }

---

### Phase 3: Testing & Polish (~1 hour)

#### 3.1 Manual Testing
**Test scenario**: End-to-end chat flow
1. Start server: `dart run bin/vide_server.dart`
2. Create network: `curl -X POST localhost:3000/api/v1/networks -d '{"initialMessage":"Hello","workingDirectory":"."}'`
3. Open SSE stream in browser or curl
4. Send message: `curl -X POST localhost:3000/api/v1/networks/{id}/messages -d '{"content":"Write hello.dart"}'`
5. Watch agent response in SSE stream

#### 3.2 Documentation
**New files**:
- `packages/vide_server/README.md` - Server setup, configuration, deployment
- `packages/vide_server/API.md` - REST API documentation with examples
- Update root `README.md` - Explain dual-interface architecture

---

## Critical Files Summary

### Files to CREATE (~8 new files, ~600 lines)

**packages/vide_core/**
- `pubspec.yaml` - Core package definition (includes Riverpod)
- `lib/vide_core.dart` - Barrel export

**packages/vide_server/** (~600 lines total for MVP)
- `pubspec.yaml` - Server package definition
- `bin/vide_server.dart` - Server entry point (100 lines)
- `lib/routes/network_routes.dart` - 3 core endpoints with SSE (200 lines)
- `lib/middleware/cors_middleware.dart` - CORS headers (40 lines)
- `lib/services/simple_permission_service.dart` - Auto-approve/deny rules (80 lines)
- `lib/dto/network_dto.dart` - Request/response schemas (100 lines)
- `lib/config/server_config.dart` - CLI arg parsing (40 lines)

### Files to MOVE to vide_core (everything non-TUI)

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

**MCP Servers (entire directories):**
- `lib/modules/mcp/memory/` → `packages/vide_core/lib/mcp/memory/`
- `lib/modules/mcp/agent/` → `packages/vide_core/lib/mcp/agent/`
- `lib/modules/mcp/task_management/` → `packages/vide_core/lib/mcp/task_management/`
- `lib/modules/mcp/git/` → `packages/vide_core/lib/mcp/git/`
- `packages/flutter_runtime_mcp/` → `packages/vide_core/packages/flutter_runtime_mcp/`

**Agent Configurations:**
- `lib/modules/agents/models/agent_configuration.dart` → `packages/vide_core/lib/agents/`
- `lib/modules/agents/configs/*.dart` → `packages/vide_core/lib/agents/`

### Files to UPDATE in vide_cli

**vide_cli changes**:
- `pubspec.yaml` - Add vide_core dependency
- Update imports in ~20-30 files to use `package:vide_core/...`

**What STAYS in vide_cli:**
- TUI pages and components (`lib/modules/agent_network/pages/`, `lib/components/`) - all nocterm UI
- Permission Service (`lib/modules/permissions/`) - shows permission dialogs to user
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
│  vide_cli (REFACTORED - TUI only)       │
│  ├─ TUI Pages & Components (nocterm)    │
│  ├─ Permission Service (dialog UI)      │
│  ├─ Entry point (bin/vide.dart)         │
│  └─ Depends on vide_core                │
└─────────────────────────────────────────┘
```

---

## Implementation Sequence

### Phase 1: Foundation - Extract vide_core (Day 1-2) **CHECKPOINT PHASE**
1. Create `packages/vide_core/` with pubspec.yaml (dependencies: claude_api, riverpod, freezed, json_serializable, etc.)
2. **Move** models to vide_core - AS-IS
3. **Move** VideConfigManager to vide_core - convert singleton to Riverpod provider (add configRoot param)
4. **Move** MemoryService to vide_core - AS-IS
5. **Move** AgentNetworkPersistenceManager to vide_core - AS-IS
6. **Move** all agent configs to vide_core - AS-IS
7. **Move** AgentNetworkManager to vide_core - AS-IS (NO changes!)
8. **Move** workingDirProvider to vide_core (just the provider definition)
9. **Move** ClaudeManager to vide_core - AS-IS
10. **Move** AgentStatusManager to vide_core - AS-IS
11. **Move** ALL MCP servers to vide_core - AS-IS
12. Update vide_cli pubspec.yaml to depend on vide_core
13. Update all imports in vide_cli
14. **Add provider overrides in TUI**: VideConfigManager (configRoot = ~/.vide), workingDirProvider
15. **Test TUI still works - STOP HERE FOR CHECKPOINT**
16. Run full TUI test suite: `dart test`
17. Manually test: agent spawning, memory persistence, all MCP servers, Git operations, Flutter runtime
18. **Only proceed to Phase 2 after TUI is 100% verified working**

### Phase 2: Build MVP REST Server (Day 3) **AFTER PHASE 1 CHECKPOINT**
19. Create `packages/vide_server/` with pubspec.yaml (dependencies: shelf, shelf_router, vide_core, riverpod)
20. Implement server entry point (bin/vide_server.dart) - create ProviderContainer with overrides
21. **Add provider overrides in REST**: VideConfigManager (configRoot = ~/.vide/api), workingDirProvider (from request)
22. Implement CORS middleware (allow all origins for localhost MVP)
23. Implement simple permission service (auto-approve safe ops, deny dangerous ops)
24. Implement network DTOs (CreateNetworkRequest, SendMessageRequest, SSEEvent)
25. Implement POST /api/v1/networks - uses AgentNetworkManager from vide_core
26. Implement POST /api/v1/networks/:id/messages - uses AgentNetworkManager
27. Implement GET /api/v1/networks/:id/agents/:agentId/stream - SSE streaming from ClaudeClient
28. **Test MVP end-to-end**: create network → send message → watch agent response in SSE stream
29. **Verify TUI still works after Phase 2 changes**

### Phase 3: Testing & Documentation (Day 4)
30. Manual testing with curl and browser (full chat conversation workflow)
31. Add error handling for common cases (network errors, invalid requests)
32. Write API documentation with curl examples (packages/vide_server/API.md)
33. Create simple HTML test client for testing SSE streaming
34. Update root README.md to explain dual-interface architecture

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

### 5. Move Everything Non-TUI in Phase 1
**Decision**: One big refactor now, not incremental refactoring later
**Why**: Goal is feature-for-feature equivalent web UI eventually
**Trade-off**: Bigger Phase 1, but avoids future refactoring pain

### 6. Use Riverpod Provider Overrides for UI-Specific Behavior
**Decision**: Inject UI-specific config via provider overrides instead of modifying core code
**Why**: Minimizes changes to Norbert's code - business logic moves AS-IS
**Examples**:
- VideConfigManager: TUI overrides with `configRoot = ~/.vide`, REST with `~/.vide/api`
- workingDirProvider: Each UI provides its own implementation
**Trade-off**: None - this is how Riverpod is meant to be used!

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
  - GET /networks/:id/agents (list agents in network)

### Phase 6: Production Readiness
- PostgreSQL/SQLite (replace file-based storage)
- Shared sessions between TUI and REST (optional)
- Multi-project workspaces
- Comprehensive test suite
- Deployment documentation
