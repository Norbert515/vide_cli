import 'dart:async';

import 'package:agent_sdk/agent_sdk.dart';

import 'gemini_client.dart';

/// Bridge that wraps [GeminiClient] and implements [AgentClient].
///
/// Since [GeminiClient] already works natively with `agent_sdk` types,
/// this bridge is pure delegation — no type mapping needed.
///
/// Also implements [Interruptible] since abort is supported via process kill.
class GeminiAgentClient implements AgentClient, Interruptible {
  final GeminiClient _inner;

  GeminiAgentClient(this._inner);

  /// Access the inner [GeminiClient] for SDK-specific operations
  /// (e.g. accessing [GeminiClient.geminiSessionId]).
  GeminiClient get innerClient => _inner;

  // ── Streams ──────────────────────────────────────────────

  @override
  Stream<AgentConversation> get conversation => _inner.conversation;

  @override
  Stream<void> get onTurnComplete => _inner.onTurnComplete;

  @override
  Stream<AgentProcessingStatus> get statusStream => _inner.statusStream;

  @override
  Stream<AgentInitData> get initDataStream => _inner.initDataStream;

  @override
  Stream<String?> get queuedMessage => _inner.queuedMessage;

  // ── Current state ────────────────────────────────────────

  @override
  AgentConversation get currentConversation => _inner.currentConversation;

  @override
  AgentProcessingStatus get currentStatus => _inner.currentStatus;

  @override
  AgentInitData? get initData => _inner.initData;

  @override
  String? get currentQueuedMessage => _inner.currentQueuedMessage;

  @override
  String get sessionId => _inner.sessionId;

  @override
  String get workingDirectory => _inner.workingDirectory;

  @override
  Future<void> get initialized => _inner.initialized;

  // ── Actions ──────────────────────────────────────────────

  @override
  void sendMessage(AgentMessage message) => _inner.sendMessage(message);

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
      _inner.injectToolResult(toolResult);

  @override
  T? getMcpServer<T>(String name) => null; // Gemini CLI manages its own tools

  // ── Interruptible ────────────────────────────────────────

  @override
  Future<void> interrupt() => _inner.abort();
}
