# Vide CLI Comprehensive Testing Plan

This document outlines a comprehensive testing strategy for Vide CLI, covering unit tests, integration tests, E2E tests, and visual tests for the TUI.

## Current State Analysis

### Existing Test Coverage

| Package | Test Files | Coverage Focus |
|---------|------------|----------------|
| **claude_api** | 20+ files (~8,292 LOC) | Protocol, models, client lifecycle |
| **vide_cli (root)** | 11 files | Permission matching, bash parsing, utilities |
| **vide_core** | **0 files** ❌ | None - critical gap |
| **moondream_api** | 3 files | Models, client, image encoding |
| **flutter_runtime_mcp** | 0 files (only examples) | None |

### Existing Test Infrastructure

1. **FakeProcess** (`packages/claude_api/test/helpers/fake_process.dart`)
   - Mock Process implementation with stream control
   - Captures stdin, simulates stdout/stderr
   - Tracks kill signals

2. **TestMcpServer / SpyMcpServer** (`packages/claude_api/test/helpers/test_mcp_server.dart`)
   - Mock MCP servers for testing
   - Lifecycle event tracking

3. **FixtureLoader** (`packages/claude_api/test/helpers/fixture_loader.dart`)
   - Loads JSON/JSONL test fixtures

4. **Test Helpers** (`packages/claude_api/test/helpers/test_helpers.dart`)
   - Factory functions for test objects (TextResponse, ToolUseResponse, etc.)

---

## Testing Strategy Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         E2E Tests                                │
│  (Full conversation flows with mocked Claude CLI)                │
├─────────────────────────────────────────────────────────────────┤
│                    Integration Tests                             │
│  (Multi-component interactions, MCP server + services)           │
├─────────────────────────────────────────────────────────────────┤
│                       Unit Tests                                 │
│  (Isolated component testing per module)                         │
├─────────────────────────────────────────────────────────────────┤
│                      Visual Tests                                │
│  (TUI component rendering snapshots)                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Unit Tests

### 1.1 vide_core Services (Priority: HIGH)

**Location:** `packages/vide_core/test/`

#### AgentNetworkManager (`services/agent_network_manager_test.dart`)
```dart
// Test cases:
group('AgentNetworkManager', () {
  // Network lifecycle
  - 'startNew creates network with main agent'
  - 'startNew sets initial task counter name'
  - 'resume restores network from persistence'
  - 'resume recreates Claude clients for all agents'
  - 'resume restores agent statuses'

  // Agent spawning
  - 'spawnAgent creates agent with correct type'
  - 'spawnAgent adds metadata to network'
  - 'spawnAgent sends initial prompt with context header'
  - 'spawnAgent throws if no active network'
  - 'spawnAgent supports all spawnable types'

  // Agent termination
  - 'terminateAgent removes agent from network'
  - 'terminateAgent aborts Claude client'
  - 'terminateAgent prevents terminating main agent'
  - 'terminateAgent supports self-termination'
  - 'terminateAgent throws for non-existent agent'

  // Inter-agent messaging
  - 'sendMessageToAgent delivers message with context header'
  - 'sendMessageToAgent throws for non-existent target'

  // Worktree management
  - 'setWorktreePath updates effective working directory'
  - 'setWorktreePath persists to network'
  - 'effectiveWorkingDirectory returns worktree if set'

  // Network updates
  - 'updateGoal updates network goal'
  - 'updateAgentName updates agent metadata'
  - 'updateAgentTaskName updates agent task name'
});
```

**Required Mocks:**
- `MockClaudeClientFactory` - Returns fake Claude clients
- `MockClaudeManager` - StateNotifier for managing clients
- `MockAgentNetworkPersistenceManager` - In-memory persistence
- `MockRef` - Riverpod ref for provider access

#### AgentNetworkPersistenceManager (`services/agent_network_persistence_manager_test.dart`)
```dart
group('AgentNetworkPersistenceManager', () {
  - 'loadNetworks returns empty list when no file exists'
  - 'loadNetworks deserializes networks from JSON'
  - 'loadNetworks handles corrupt JSON gracefully'
  - 'saveNetwork creates persistence file'
  - 'saveNetwork updates existing network'
  - 'deleteNetwork removes network from file'
  - 'networks are ordered by lastActiveAt'
  - 'persistence file location follows XDG spec'
});
```

#### MemoryService (`services/memory_service_test.dart`)
```dart
group('MemoryService', () {
  - 'save stores key-value pair'
  - 'retrieve returns stored value'
  - 'retrieve returns null for non-existent key'
  - 'delete removes key-value pair'
  - 'list returns all entries for scope'
  - 'entries are scoped by project path'
  - 'handles concurrent read/write correctly'
  - 'persists across service instances'
});
```

#### PermissionChecker (`services/permissions/permission_checker_test.dart`)
```dart
group('PermissionChecker', () {
  - 'check returns deny for denied patterns'
  - 'check returns allow for allowed patterns'
  - 'check returns ask when no pattern matches'
  - 'deny patterns take precedence over allow'
  - 'session cache is checked before persistent patterns'
  - 'addSessionPattern adds pattern to cache'
  - 'clearSessionCache removes all session patterns'
  - 'safe commands are auto-approved'
});
```

#### LocalSettingsManager (`services/settings/local_settings_manager_test.dart`)
```dart
group('LocalSettingsManager', () {
  - 'readSettings returns empty settings when file missing'
  - 'readSettings deserializes settings from JSON'
  - 'addToAllowList appends pattern'
  - 'addToDenyList appends pattern'
  - 'saveSettings persists to .claude/settings.local.json'
  - 'handles malformed JSON gracefully'
});
```

#### ClaudeClientFactory (`services/claude_client_factory_test.dart`)
```dart
group('ClaudeClientFactory', () {
  - 'create returns configured ClaudeClient'
  - 'createSync returns client immediately'
  - 'uses effective working directory from getter'
  - 'applies agent configuration to client'
  - 'registers MCP servers for agent'
});
```

### 1.2 vide_core MCP Servers (Priority: HIGH)

#### AgentMCPServer (`mcp/agent/agent_mcp_server_test.dart`)
```dart
group('AgentMCPServer', () {
  group('spawnAgent tool', () {
    - 'spawns implementation agent'
    - 'spawns contextCollection agent'
    - 'spawns flutterTester agent'
    - 'spawns planning agent'
    - 'returns error for unknown agent type'
    - 'returns agent ID in result'
  });

  group('sendMessageToAgent tool', () {
    - 'sends message to target agent'
    - 'returns error for non-existent agent'
  });

  group('setAgentStatus tool', () {
    - 'sets status to working'
    - 'sets status to waitingForAgent'
    - 'sets status to waitingForUser'
    - 'sets status to idle'
    - 'returns error for invalid status'
  });

  group('terminateAgent tool', () {
    - 'terminates target agent'
    - 'handles self-termination'
    - 'returns error for main agent'
  });

  group('setSessionWorktree tool', () {
    - 'sets worktree path'
    - 'clears worktree with empty path'
    - 'validates directory exists'
  });
});
```

#### GitMCPServer (`mcp/git/git_server_test.dart`)
```dart
group('GitMCPServer', () {
  // Git operations (using temp repo)
  - 'gitStatus returns correct status'
  - 'gitAdd stages files'
  - 'gitCommit creates commit'
  - 'gitDiff shows changes'
  - 'gitLog returns commit history'
  - 'gitBranch lists branches'
  - 'gitCheckout switches branch'

  // Worktree operations
  - 'gitWorktreeAdd creates worktree'
  - 'gitWorktreeList lists worktrees'
  - 'gitWorktreeRemove removes worktree'

  // Merge/rebase
  - 'gitMerge merges branches'
  - 'gitRebase rebases branch'

  // Error handling
  - 'returns error for non-git directory'
  - 'returns error for invalid branch'
});
```

#### MemoryMCPServer (`mcp/memory_mcp_server_test.dart`)
```dart
group('MemoryMCPServer', () {
  - 'memorySave stores value'
  - 'memoryRetrieve returns value'
  - 'memoryDelete removes value'
  - 'memoryList returns all entries'
});
```

#### TaskManagementMCPServer (`mcp/task_management/task_management_server_test.dart`)
```dart
group('TaskManagementMCPServer', () {
  - 'setTaskName updates network goal'
});
```

### 1.3 vide_core State Management (Priority: MEDIUM)

#### AgentStatusManager (`state/agent_status_manager_test.dart`)
```dart
group('AgentStatusManager', () {
  - 'initial status is working'
  - 'setStatus updates status'
  - 'notifies listeners on change'
  - 'family provider creates separate instances per agent'
});
```

#### ClaudeManager (`services/claude_manager_test.dart`)
```dart
group('ClaudeManager', () {
  - 'addAgent adds client to map'
  - 'removeAgent removes client from map'
  - 'getClient returns client for agent'
  - 'getClient returns null for non-existent agent'
});
```

### 1.4 vide_core Models (Priority: MEDIUM)

#### Model Serialization (`models/*_test.dart`)
```dart
group('AgentNetwork', () {
  - 'serializes to JSON correctly'
  - 'deserializes from JSON correctly'
  - 'copyWith preserves unchanged fields'
  - 'copyWith updates specified fields'
  - 'clearWorktreePath removes worktree'
});

group('AgentMetadata', () {
  - 'serializes to JSON correctly'
  - 'deserializes from JSON correctly'
  - 'includes all agent properties'
});

group('AgentStatus', () {
  - 'fromString parses all statuses'
  - 'toString returns correct strings'
});

group('ClaudeSettings', () {
  - 'serializes allowList'
  - 'serializes denyList'
  - 'handles empty lists'
});

group('MemoryEntry', () {
  - 'serializes key, value, projectPath'
  - 'handles null projectPath'
});
```

### 1.5 Agent Configurations (Priority: LOW)

#### Agent Configs (`agents/*_config_test.dart`)
```dart
// For each agent type:
group('ImplementationAgentConfig', () {
  - 'creates valid configuration'
  - 'includes required system prompt sections'
  - 'includes correct MCP servers'
});
// Repeat for: MainAgentConfig, ContextCollectionAgentConfig,
//             FlutterTesterAgentConfig, PlanningAgentConfig
```

### 1.6 Utilities (Priority: MEDIUM)

#### ProjectDetector (`utils/project_detector_test.dart`)
```dart
group('ProjectDetector', () {
  - 'detects Flutter project'
  - 'detects Dart project'
  - 'detects unknown project type'
  - 'handles nested pubspec.yaml'
});
```

### 1.7 TUI Components (Priority: MEDIUM)

These tests verify component rendering logic (not visual output).

#### DiffRenderer (`components/diff_renderer_test.dart`)
```dart
group('DiffRenderer', () {
  - 'parses line format correctly (number→content)'
  - 'detects added lines'
  - 'detects removed lines'
  - 'detects unchanged lines'
  - 'handles empty result gracefully'
  - 'falls back to DefaultRenderer on invalid format'
  - 'formats relative path correctly'
});
```

#### PermissionDialog Logic (`components/permission_dialog_test.dart`)
```dart
group('PermissionDialog', () {
  - 'formats tool invocation display correctly'
  - 'handles all permission options'
  - 'extracts domain from WebFetch URL'
  - 'extracts pattern for file operations'
});
```

---

## 2. Integration Tests

### 2.1 Agent Network Flow (`test/integration/agent_network_flow_test.dart`)

Test full agent lifecycle without real Claude CLI.

```dart
group('Agent Network Flow Integration', () {
  - 'starts network and spawns agent'
  - 'agents can message each other'
  - 'agent termination cleans up resources'
  - 'network persistence survives restart'
  - 'worktree switching affects new agents'
});
```

**Setup:**
```dart
// Use MockClaudeClientFactory that returns FakeClaudeClient
// FakeClaudeClient simulates responses via stream controller
late ProviderContainer container;
late FakeClaudeClientFactory clientFactory;
late Directory tempDir;

setUp(() async {
  tempDir = await Directory.systemTemp.createTemp('vide_test_');
  clientFactory = FakeClaudeClientFactory();
  container = ProviderContainer(
    overrides: [
      workingDirProvider.overrideWithValue(tempDir.path),
      claudeClientFactoryProvider.overrideWithValue(clientFactory),
    ],
  );
});
```

### 2.2 MCP Server + Service Integration (`test/integration/mcp_integration_test.dart`)

```dart
group('MCP + Service Integration', () {
  - 'AgentMCPServer spawnAgent creates real agent in manager'
  - 'MemoryMCPServer persists to MemoryService'
  - 'GitMCPServer operates on real git repository'
  - 'TaskManagementMCPServer updates network goal'
});
```

### 2.3 Permission Flow Integration (`test/integration/permission_flow_test.dart`)

```dart
group('Permission Flow', () {
  - 'PermissionChecker respects LocalSettingsManager'
  - 'Session patterns override persistent patterns'
  - 'Pattern inference generates correct patterns'
  - 'Safe commands bypass permission check'
});
```

---

## 3. E2E Tests (with Mocked Claude CLI)

### 3.1 Mock Claude CLI Strategy

Create a **MockClaudeCLI** that simulates the Claude CLI JSON protocol without making real API calls.

**Location:** `test/e2e/helpers/mock_claude_cli.dart`

```dart
/// Mock Claude CLI that simulates responses
class MockClaudeCLI {
  final StreamController<String> _stdout = StreamController();
  final List<String> _receivedMessages = [];
  final Map<String, MockToolHandler> _toolHandlers = {};

  Stream<String> get stdout => _stdout.stream;
  List<String> get receivedMessages => _receivedMessages;

  /// Register a handler for tool calls
  void onTool(String toolName, MockToolHandler handler) {
    _toolHandlers[toolName] = handler;
  }

  /// Simulate receiving a message from the user
  void receiveMessage(String jsonLine) {
    final parsed = jsonDecode(jsonLine);
    _receivedMessages.add(parsed['message']);
    // Trigger response based on test scenario
  }

  /// Emit a text response
  void emitTextResponse(String text) {
    _stdout.add(jsonEncode({
      'type': 'assistant',
      'message': {'type': 'text', 'text': text},
    }));
  }

  /// Emit a tool use request
  void emitToolUse(String toolName, Map<String, dynamic> params) {
    _stdout.add(jsonEncode({
      'type': 'assistant',
      'message': {
        'type': 'tool_use',
        'tool_name': toolName,
        'tool_input': params,
      },
    }));
  }

  /// Emit turn complete
  void emitTurnComplete() {
    _stdout.add(jsonEncode({'type': 'result', 'result': 'turn_complete'}));
  }
}

typedef MockToolHandler = String Function(Map<String, dynamic> params);
```

### 3.2 E2E Test Scenarios

**Location:** `test/e2e/`

#### Basic Conversation (`e2e/basic_conversation_test.dart`)
```dart
@Tags(['e2e'])
group('Basic Conversation E2E', () {
  - 'sends message and receives text response'
  - 'handles multi-turn conversation'
  - 'conversation state transitions correctly'
});
```

#### Agent Spawning E2E (`e2e/agent_spawning_test.dart`)
```dart
@Tags(['e2e'])
group('Agent Spawning E2E', () {
  - 'main agent spawns implementation agent via MCP tool'
  - 'spawned agent receives initial prompt'
  - 'spawned agent can message back to main'
  - 'main agent terminates spawned agent'
});
```

#### Tool Invocation E2E (`e2e/tool_invocation_test.dart`)
```dart
@Tags(['e2e'])
group('Tool Invocation E2E', () {
  - 'file read tool invocation is processed'
  - 'bash command requires permission'
  - 'edit tool shows diff in response'
});
```

#### Permission Dialog E2E (`e2e/permission_dialog_test.dart`)
```dart
@Tags(['e2e'])
group('Permission Dialog E2E', () {
  - 'permission dialog appears for unallowed tool'
  - 'allowing permission continues execution'
  - 'denying permission returns error to Claude'
  - 'allow and remember persists pattern'
});
```

### 3.3 E2E Test Infrastructure

**FakeClaudeClient** (`test/e2e/helpers/fake_claude_client.dart`)
```dart
/// A ClaudeClient backed by MockClaudeCLI for E2E testing
class FakeClaudeClient implements ClaudeClient {
  final MockClaudeCLI _mockCli;
  final _conversation = BehaviorSubject<Conversation>.seeded(
    Conversation.empty(),
  );

  @override
  Stream<Conversation> get conversation => _conversation.stream;

  @override
  void sendMessage(Message message) {
    // Add to conversation
    // Trigger mock CLI response
  }

  /// Test helper: trigger a response
  void simulateResponse(List<ResponseContent> content) {
    // Update conversation with assistant message
  }
}
```

---

## 4. Visual Tests (TUI Snapshots)

### 4.1 Approach: Golden File Testing

Since Vide uses **nocterm** (a terminal UI framework), we can capture rendered output and compare against golden files.

**Strategy:**
1. Render component to a string buffer
2. Compare output against saved golden file
3. Update goldens when intentional changes are made

### 4.2 Visual Test Framework

**Location:** `test/visual/`

```dart
/// Helper for visual component testing
class VisualTestHarness {
  final int width;
  final int height;
  late final StringBuffer _output;

  VisualTestHarness({this.width = 80, this.height = 24});

  /// Render a component and return string output
  String render(Component component) {
    // Use nocterm's render-to-string capability
    // or implement a test terminal backend
  }

  /// Compare against golden file
  void expectGolden(String output, String goldenPath) {
    final goldenFile = File(goldenPath);
    if (Platform.environment['UPDATE_GOLDENS'] == 'true') {
      goldenFile.writeAsStringSync(output);
      return;
    }
    expect(output, equals(goldenFile.readAsStringSync()));
  }
}
```

### 4.3 Visual Test Cases

#### DiffRenderer Visual (`visual/diff_renderer_visual_test.dart`)
```dart
group('DiffRenderer Visual', () {
  - 'renders added lines in green'
  - 'renders removed lines in red'
  - 'renders unchanged lines normally'
  - 'renders file header correctly'
  - 'renders error state correctly'
});
```

#### PermissionDialog Visual (`visual/permission_dialog_visual_test.dart`)
```dart
group('PermissionDialog Visual', () {
  - 'renders Bash permission request'
  - 'renders Read permission request'
  - 'renders WebFetch permission request'
  - 'shows all action buttons'
});
```

#### TerminalOutputRenderer Visual (`visual/terminal_output_visual_test.dart`)
```dart
group('TerminalOutputRenderer Visual', () {
  - 'renders command output correctly'
  - 'handles ANSI color codes'
  - 'handles carriage returns'
  - 'truncates long output'
});
```

#### AgentStatus Visual (`visual/agent_status_visual_test.dart`)
```dart
group('AgentStatus Visual', () {
  - 'renders working status'
  - 'renders waiting status'
  - 'renders idle status'
  - 'renders multiple agents in bar'
});
```

#### NetworkExecutionPage Visual (`visual/network_execution_visual_test.dart`)
```dart
group('NetworkExecutionPage Visual', () {
  - 'renders empty conversation'
  - 'renders user message'
  - 'renders assistant message'
  - 'renders tool invocation'
  - 'renders context usage bar'
});
```

### 4.4 Golden File Organization

```
test/visual/goldens/
├── diff_renderer/
│   ├── added_lines.golden
│   ├── removed_lines.golden
│   ├── mixed_diff.golden
│   └── error_state.golden
├── permission_dialog/
│   ├── bash_permission.golden
│   ├── read_permission.golden
│   └── web_fetch_permission.golden
├── terminal_output/
│   ├── simple_output.golden
│   ├── ansi_colors.golden
│   └── long_output.golden
└── agent_status/
    ├── working.golden
    ├── waiting.golden
    └── idle.golden
```

### 4.5 Updating Goldens

```bash
# Update all golden files
UPDATE_GOLDENS=true dart test test/visual/

# Update specific golden
UPDATE_GOLDENS=true dart test test/visual/diff_renderer_visual_test.dart
```

---

## 5. Test Infrastructure Requirements

### 5.1 New Mock Classes Needed

| Mock | Purpose |
|------|---------|
| `MockClaudeClient` | Simulates Claude API responses |
| `MockClaudeClientFactory` | Returns mock clients |
| `MockAgentNetworkManager` | Simulates agent orchestration |
| `MockAgentNetworkPersistenceManager` | In-memory network storage |
| `MockMemoryService` | In-memory key-value storage |
| `MockLocalSettingsManager` | In-memory settings |
| `MockPermissionService` | Auto-approve/deny permissions |
| `FakeGitRepository` | Temp git repo for testing |

### 5.2 Test Fixtures to Create

**Location:** `test/fixtures/`

```
fixtures/
├── conversations/
│   ├── simple_conversation.json
│   ├── multi_turn.json
│   ├── tool_invocation.json
│   └── agent_network.json
├── networks/
│   ├── empty_network.json
│   ├── with_agents.json
│   └── with_worktree.json
├── tool_results/
│   ├── read_success.json
│   ├── edit_success.json
│   ├── bash_output.json
│   └── error_result.json
└── permissions/
    ├── settings_with_allow.json
    ├── settings_with_deny.json
    └── empty_settings.json
```

### 5.3 Test Tags

```yaml
# dart_test.yaml
tags:
  e2e:
    timeout: 120s
  visual:
    timeout: 30s
  slow:
    timeout: 60s
```

```bash
# Run only unit tests (fast)
dart test --exclude-tags e2e,visual,slow

# Run E2E tests
dart test --tags e2e

# Run visual tests
dart test --tags visual

# Run all tests
dart test
```

---

## 6. Implementation Phases

### Phase 1: Core vide_core Unit Tests (Week 1-2)
- [ ] Set up test infrastructure for vide_core
- [ ] Create mock classes
- [ ] Write AgentNetworkManager tests
- [ ] Write MCP server tests
- [ ] Write PermissionChecker tests
- [ ] Write model serialization tests

### Phase 2: Integration Tests (Week 2-3)
- [ ] Create FakeClaudeClient
- [ ] Write agent network flow tests
- [ ] Write MCP + service integration tests
- [ ] Write permission flow tests

### Phase 3: E2E Tests with Mock CLI (Week 3-4)
- [ ] Create MockClaudeCLI
- [ ] Write conversation flow E2E tests
- [ ] Write agent spawning E2E tests
- [ ] Write tool invocation E2E tests

### Phase 4: Visual Tests (Week 4-5)
- [ ] Create VisualTestHarness
- [ ] Generate initial golden files
- [ ] Write DiffRenderer visual tests
- [ ] Write PermissionDialog visual tests
- [ ] Write other component visual tests

### Phase 5: CI Integration (Week 5)
- [ ] Add test jobs to GitHub Actions
- [ ] Configure test tags for parallel execution
- [ ] Set up golden file management
- [ ] Add coverage reporting

---

## 7. Test Commands

```bash
# Run all tests (excluding e2e and slow)
dart test --exclude-tags e2e,slow

# Run with coverage
dart test --coverage=coverage

# Generate coverage report
dart run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html

# Run specific test file
dart test test/path/to/test_file.dart

# Run tests matching pattern
dart test --name "AgentNetworkManager"

# Run only vide_core tests
dart test packages/vide_core/test/

# Run visual tests and update goldens
UPDATE_GOLDENS=true dart test test/visual/
```

---

## 8. Coverage Goals

| Package | Target Coverage |
|---------|-----------------|
| vide_core (services) | 80% |
| vide_core (MCP servers) | 90% |
| vide_core (models) | 95% |
| vide_cli (components) | 70% |
| claude_api | Maintain existing |

---

## 9. Open Questions

1. **Visual Testing Framework**: nocterm may need modifications to support rendering to string for testing. Need to investigate if this is already supported or requires implementation.

2. **Mock Claude CLI Fidelity**: How closely should MockClaudeCLI simulate the real protocol? Should it include error scenarios, rate limiting, etc.?

3. **Flutter Runtime MCP Tests**: Should we test Flutter app management with real Flutter processes or mock entirely?

4. **Permission Dialog Testing**: How do we test interactive permission dialogs in E2E tests? Possible approaches:
   - Auto-approve all permissions
   - Use test-specific permission patterns
   - Implement dialog interaction simulation

5. **Parallel Test Execution**: Some tests (git operations, file I/O) may conflict when run in parallel. Need isolation strategy.

---

## 10. Dependencies to Add

```yaml
# pubspec.yaml (dev_dependencies)
dev_dependencies:
  test: ^1.24.0
  mocktail: ^1.0.0  # For creating mocks
  fake_async: ^1.3.0  # For time-based testing
  stream_transform: ^2.1.0  # For stream testing
```

---

## Next Steps

1. Review this plan and provide feedback
2. Prioritize test areas based on risk/impact
3. Create initial mock classes
4. Begin Phase 1 implementation

