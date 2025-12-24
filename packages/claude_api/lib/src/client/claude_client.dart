import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../models/config.dart';
import '../models/message.dart';
import '../models/response.dart';
import '../models/conversation.dart';
import '../mcp/server/mcp_server_base.dart';
import '../protocol/json_decoder.dart';
import '../control/control_types.dart';
import 'conversation_loader.dart';
import 'process_manager.dart';
import 'response_processor.dart';
import 'process_lifecycle_manager.dart';

abstract class ClaudeClient {
  Stream<Conversation> get conversation;
  Conversation get currentConversation;
  String get sessionId;
  void sendMessage(Message message);
  Future<void> close();
  Future<void> abort();
  bool get isAborting;

  String get workingDirectory;

  /// Emits when a conversation turn completes (assistant finishes responding).
  /// This is the clean way to detect when an agent has finished its work.
  Stream<void> get onTurnComplete;

  T? getMcpServer<T extends McpServerBase>(String name);

  factory ClaudeClient({ClaudeConfig? config, List<McpServerBase>? mcpServers}) = ClaudeClientImpl;

  static Future<ClaudeClient> create({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
  }) async {
    final client = ClaudeClientImpl(
      config: config ?? ClaudeConfig.defaults(),
      mcpServers: mcpServers,
      hooks: hooks,
      canUseTool: canUseTool,
    );
    await client.init();
    return client;
  }
}

class ClaudeClientImpl implements ClaudeClient {
  ClaudeConfig config;
  final List<McpServerBase> mcpServers;
  @override
  final String sessionId;
  final JsonDecoder _decoder = JsonDecoder();

  /// Hook configuration for control protocol
  final Map<HookEvent, List<HookMatcher>>? hooks;

  /// Permission callback for control protocol
  final CanUseToolCallback? canUseTool;

  /// Response processor for handling Claude responses
  final ResponseProcessor _responseProcessor = ResponseProcessor();

  /// Process lifecycle manager for process management
  final ProcessLifecycleManager _lifecycleManager = ProcessLifecycleManager();

  bool _isInitialized = false;
  bool _isFirstMessage = true;

  @override
  bool get isAborting => _lifecycleManager.isAborting;

  // Conversation state management - persistent across process invocations
  final _conversationController = StreamController<Conversation>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  Conversation _currentConversation = Conversation.empty();

  @override
  Stream<Conversation> get conversation => _conversationController.stream;

  @override
  Stream<void> get onTurnComplete => _turnCompleteController.stream;

  @override
  Conversation get currentConversation => _currentConversation;

  ClaudeClientImpl({
    ClaudeConfig? config,
    List<McpServerBase>? mcpServers,
    this.hooks,
    this.canUseTool,
  })  : config = config ?? ClaudeConfig.defaults(),
        mcpServers = mcpServers ?? [],
        sessionId = config?.sessionId ?? const Uuid().v4() {
    // Update config with session ID if not already set
    if (this.config.sessionId == null) {
      this.config = this.config.copyWith(sessionId: sessionId);
    }
    if (this.config.workingDirectory == null) {
      this.config = this.config.copyWith(workingDirectory: Directory.current.path);
    }
  }

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    if (await ConversationLoader.hasConversation(sessionId, config.workingDirectory!)) {
      final conversation = await ConversationLoader.loadHistoryForDisplay(sessionId, config.workingDirectory!);
      _currentConversation = conversation;
      _conversationController.add(conversation);
      _isFirstMessage = false;
    } else {
      _isFirstMessage = true;
    }

    _isInitialized = true;

    // Start MCP servers
    for (int i = 0; i < mcpServers.length; i++) {
      final server = mcpServers[i];
      // Skip if server is already running (e.g., shared servers between agents)
      if (server.isRunning) {
        continue;
      }

      await server.start();
    }

    // Control protocol is always required
    await _startControlProtocol();
  }

  /// Start a persistent process with control protocol
  Future<void> _startControlProtocol() async {
    final processManager = ProcessManager(config: config, mcpServers: mcpServers);
    final args = config.toCliArgs(isFirstMessage: _isFirstMessage);

    final mcpArgs = await processManager.getMcpArgs();
    if (mcpArgs.isNotEmpty) {
      args.insertAll(0, mcpArgs);
    }

    // Delegate process start to lifecycle manager
    final controlProtocol = await _lifecycleManager.startProcess(
      config: config,
      args: args,
      hooks: hooks,
      canUseTool: canUseTool,
    );

    // Listen to messages from control protocol
    controlProtocol.messages.listen(_handleControlProtocolMessage);
  }

  /// Handle messages from the control protocol
  void _handleControlProtocolMessage(Map<String, dynamic> json) {
    final response = _decoder.decodeSingle(jsonEncode(json));
    if (response == null) return;

    // Delegate response processing to ResponseProcessor
    final result = _responseProcessor.processResponse(response, _currentConversation);
    _updateConversation(result.updatedConversation);

    if (result.turnComplete) {
      _turnCompleteController.add(null);
    }
  }

  @override
  T? getMcpServer<T extends McpServerBase>(String name) {
    try {
      return mcpServers.whereType<T>().firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  void _updateConversation(Conversation newConversation) {
    final oldState = _currentConversation.state;
    final newState = newConversation.state;

    if (oldState != newState) {}

    _currentConversation = newConversation;
    _conversationController.add(_currentConversation);
  }

  @override
  void sendMessage(Message message) {
    if (message.text.trim().isEmpty) {
      return;
    }

    // Control protocol is always required
    final controlProtocol = _lifecycleManager.controlProtocol;
    if (controlProtocol == null) {
      throw StateError(
        'Control protocol is not initialized. '
        'Ensure init() was called before sendMessage().',
      );
    }

    // Add user message to conversation
    final userMessage = ConversationMessage.user(content: message.text, attachments: message.attachments);
    _updateConversation(_currentConversation.addMessage(userMessage).withState(ConversationState.sendingMessage));

    // Send via control protocol
    if (message.attachments != null && message.attachments!.isNotEmpty) {
      // Build content array with attachments
      final content = <Map<String, dynamic>>[
        {'type': 'text', 'text': message.text},
        ...message.attachments!.map((a) => a.toClaudeJson()),
      ];
      controlProtocol.sendUserMessageWithContent(content);
    } else {
      controlProtocol.sendUserMessage(message.text);
    }
  }

  @override
  Future<void> abort() async {
    if (!_lifecycleManager.isRunning) {
      return;
    }

    try {
      // Delegate abort to lifecycle manager
      await _lifecycleManager.abort();

      // Add synthetic abort message to conversation
      final assistantId = DateTime.now().millisecondsSinceEpoch.toString();
      final abortMessage = ConversationMessage.assistant(
        id: assistantId,
        responses: [
          ErrorResponse(
            id: assistantId,
            timestamp: DateTime.now(),
            error: 'Interrupted by user',
            details: 'Process stopped by user (Ctrl+C)',
          ),
        ],
        isStreaming: false,
        isComplete: true,
      );

      // Update conversation state
      _updateConversation(_currentConversation.addMessage(abortMessage).withState(ConversationState.idle));
    } catch (e) {
      _updateConversation(_currentConversation.withError('Failed to abort: $e'));
    }
  }

  Future<void> clearConversation() async {
    _updateConversation(Conversation.empty());
    // Reset to first message for new conversation
    _isFirstMessage = true;
  }

  @override
  Future<void> close() async {
    // Delegate process cleanup to lifecycle manager
    await _lifecycleManager.close();

    // Stop all MCP servers
    for (final server in mcpServers) {
      await server.stop();
    }

    // Close streams
    await _conversationController.close();
    await _turnCompleteController.close();

    _isInitialized = false;
  }

  Future<void> restart() async {
    await close();
    _isFirstMessage = true;
  }

  @override
  String get workingDirectory => config.workingDirectory!;
}
