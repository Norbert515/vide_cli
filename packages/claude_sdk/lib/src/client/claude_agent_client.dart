import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart';

import '../bridge/type_mappers.dart';
import 'claude_client.dart';

/// Bridge that wraps a [ClaudeClient] and exposes it as an [AgentClient].
///
/// Also implements extended capability interfaces for Claude-specific features
/// like model switching, permission modes, interrupting, and file rewind.
///
/// Usage:
/// ```dart
/// final claude = ClaudeClient.createNonBlocking(config: config);
/// final agent = ClaudeAgentClient(claude);
/// // Use agent as AgentClient everywhere
/// ```
class ClaudeAgentClient
    implements
        AgentClient,
        ModelConfigurable,
        PermissionModeConfigurable,
        ThinkingConfigurable,
        Interruptible,
        FileRewindable,
        McpConfigurable {
  final ClaudeClient _inner;

  ClaudeAgentClient(this._inner);

  /// Access the underlying [ClaudeClient] for SDK-specific operations
  /// that have no generic equivalent (e.g., hooks, control protocol).
  ClaudeClient get innerClient => _inner;

  // ── AgentClient: Streams ─────────────────────────────────

  @override
  Stream<AgentConversation> get conversation =>
      _inner.conversation.map(AgentConversationMapper.fromClaude);

  @override
  Stream<void> get onTurnComplete => _inner.onTurnComplete;

  @override
  Stream<AgentProcessingStatus> get statusStream =>
      _inner.statusStream.map(AgentStatusMapper.fromClaude);

  @override
  Stream<AgentInitData> get initDataStream =>
      _inner.initDataStream.map(AgentInitDataMapper.fromClaude);

  @override
  Stream<String?> get queuedMessage => _inner.queuedMessage;

  // ── AgentClient: Current state ───────────────────────────

  @override
  AgentConversation get currentConversation =>
      AgentConversationMapper.fromClaude(_inner.currentConversation);

  @override
  AgentProcessingStatus get currentStatus =>
      AgentStatusMapper.fromClaude(_inner.currentStatus);

  @override
  AgentInitData? get initData => _inner.initData == null
      ? null
      : AgentInitDataMapper.fromClaude(_inner.initData!);

  @override
  String? get currentQueuedMessage => _inner.currentQueuedMessage;

  @override
  String get sessionId => _inner.sessionId;

  @override
  String get workingDirectory => _inner.workingDirectory;

  @override
  Future<void> get initialized => _inner.initialized;

  // ── AgentClient: Actions ─────────────────────────────────

  @override
  void sendMessage(AgentMessage message) =>
      _inner.sendMessage(AgentMessageMapper.toClaude(message));

  @override
  Future<void> abort() => _inner.abort();

  @override
  Future<void> close() => _inner.close();

  @override
  Future<void> clearConversation() => _inner.clearConversation();

  @override
  void clearQueuedMessage() => _inner.clearQueuedMessage();

  @override
  void injectToolResult(AgentToolResultResponse toolResult) =>
      _inner.injectToolResult(AgentToolResultMapper.toClaude(toolResult));

  @override
  T? getMcpServer<T>(String name) {
    // ClaudeClient constrains T to McpServerBase. AgentClient uses
    // unconstrained T for an SDK-agnostic interface. Use dynamic dispatch
    // to bypass the generic bound at the call site.
    final dynamic inner = _inner;
    try {
      return inner.getMcpServer(name) as T?;
    } catch (_) {
      return null;
    }
  }

  // ── Extended capabilities ────────────────────────────────

  @override
  Future<void> setModel(String model) async {
    await _inner.setModel(model);
  }

  @override
  Future<void> setPermissionMode(String mode) => _inner.setPermissionMode(mode);

  @override
  Future<void> setMaxThinkingTokens(int maxTokens) async {
    await _inner.setMaxThinkingTokens(maxTokens);
  }

  @override
  Future<void> interrupt() => _inner.interrupt();

  @override
  Future<void> rewindFiles(String userMessageId) =>
      _inner.rewindFiles(userMessageId);

  @override
  Future<void> setMcpServers(
    List<AgentMcpServerConfig> servers, {
    bool replace = false,
  }) {
    return _inner.setMcpServers(
      servers.map(AgentMcpServerConfigMapper.toClaude).toList(),
      replace: replace,
    );
  }

  @override
  Future<AgentMcpStatusInfo> getMcpStatus() async {
    final result = await _inner.getMcpStatus();
    return AgentMcpStatusMapper.fromClaude(result);
  }
}
