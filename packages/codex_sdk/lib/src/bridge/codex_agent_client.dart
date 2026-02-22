import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart';
import 'package:claude_sdk/claude_sdk.dart';

import '../client/codex_client.dart';

/// Bridge that wraps a [CodexClient] and exposes it as an [AgentClient].
///
/// Also implements [Interruptible] for graceful abort support.
///
/// Codex does NOT support model switching, permission mode changes,
/// thinking configuration, file rewind, or dynamic MCP server configuration,
/// so those capability interfaces are intentionally omitted.
class CodexAgentClient implements AgentClient, Interruptible {
  final CodexClient _inner;

  CodexAgentClient(this._inner);

  /// Access the underlying [CodexClient] for SDK-specific operations.
  CodexClient get innerClient => _inner;

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
    final dynamic inner = _inner;
    try {
      return inner.getMcpServer(name) as T?;
    } catch (_) {
      return null;
    }
  }

  // ── Interruptible ────────────────────────────────────────

  @override
  Future<void> interrupt() => _inner.abort();
}
