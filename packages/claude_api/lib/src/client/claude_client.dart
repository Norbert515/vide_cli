import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:claude_api/claude_api.dart';
import 'package:uuid/uuid.dart';
import '../protocol/json_decoder.dart';

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

  static Future<ClaudeClient> create({ClaudeConfig? config, List<McpServerBase>? mcpServers}) async {
    final client = ClaudeClientImpl(config: config ?? ClaudeConfig.defaults(), mcpServers: mcpServers);
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

  bool _isInitialized = false;
  bool _isFirstMessage = true;
  String? _latestConversationUuid;

  // Process management for abort functionality
  Process? _activeProcess;
  bool _isAborting = false;

  // Message inbox for handling concurrent messages from sub-agents.
  // When a process is active, incoming messages are queued in the inbox
  // and processed when the current turn completes.
  final List<Message> _inbox = [];
  StreamSubscription<void>? _inboxSubscription;

  @override
  bool get isAborting => _isAborting;

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

  ClaudeClientImpl({ClaudeConfig? config, List<McpServerBase>? mcpServers})
    : config = config ?? ClaudeConfig.defaults(),
      mcpServers = mcpServers ?? [],
      sessionId = config?.sessionId ?? const Uuid().v4() {
    // Update config with session ID if not already set
    if (this.config.sessionId == null) {
      this.config = this.config.copyWith(sessionId: sessionId);
    }
    if (this.config.workingDirectory == null) {
      this.config = this.config.copyWith(workingDirectory: Directory.current.path);
    }

    // Set up inbox processing - when a turn completes, process any queued messages
    _inboxSubscription = onTurnComplete.listen((_) => _processInbox());
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

    // Queue message in inbox if a process is already active.
    // This prevents race conditions when multiple sub-agents report back simultaneously.
    // Messages will be processed in order when the current turn completes.
    if (_activeProcess != null) {
      print('[ClaudeClient] Process busy, adding message to inbox (inbox size: ${_inbox.length + 1})');
      _inbox.add(message);
      return;
    }

    _processMessageFromInbox(message);
  }

  /// Process the next message from the inbox when a turn completes.
  void _processInbox() {
    if (_inbox.isEmpty) {
      return;
    }

    // Don't process if already busy (shouldn't happen, but be safe)
    if (_activeProcess != null) {
      print('[ClaudeClient] WARNING: _processInbox called while process is active');
      return;
    }

    final nextMessage = _inbox.removeAt(0);
    print('[ClaudeClient] Processing message from inbox (${_inbox.length} remaining)');
    _processMessageFromInbox(nextMessage);
  }

  void _processMessageFromInbox(Message message) {
    final hasAttachments = message.attachments != null && message.attachments!.isNotEmpty;

    // Add user message to conversation
    final userMessage = ConversationMessage.user(content: message.text, attachments: message.attachments);
    _updateConversation(_currentConversation.addMessage(userMessage).withState(ConversationState.sendingMessage));

    // Send message to Claude
    _sendToClaudeProcess(message.text, attachments: message.attachments);
  }

  Future<void> _sendToClaudeProcess(String text, {List<Attachment>? attachments}) async {
    if (!_isInitialized) {
      print('[ClaudeClient] Not initialized, initializing...');
    }

    try {
      // Update state to receiving
      _updateConversation(_currentConversation.withState(ConversationState.receivingResponse));

      // Build CLI arguments with message
      // Add MCP configs if available
      final processManager = ProcessManager(config: config, mcpServers: mcpServers);

      // Use latest conversation UUID if available, otherwise use session ID
      final configToUse = _latestConversationUuid != null
          ? config.copyWith(sessionId: _latestConversationUuid)
          : config;

      // When attachments are present, use stream-json input format
      final hasAttachments = attachments != null && attachments.isNotEmpty;
      final args = configToUse.toCliArgs(
        isFirstMessage: _isFirstMessage,
        message: hasAttachments ? null : text,
        useJsonInput: hasAttachments,
      );

      // Don't print full args as they contain the entire system prompt - too verbose

      final mcpArgs = await processManager.getMcpArgs();
      if (mcpArgs.isNotEmpty) {
        // Only log MCP server count, not full args
        final mcpServerCount = mcpServers.length;
        args.insertAll(0, mcpArgs);
      }

      // Start NEW process for this message
      final process = await Process.start(
        'claude',
        args,
        environment: <String, String>{'MCP_TOOL_TIMEOUT': '30000000'},
        runInShell: true,
        includeParentEnvironment: true,
        workingDirectory: config.workingDirectory,
      );
      _activeProcess = process;
      _isAborting = false;
      print('[ClaudeClient] Process started with PID: ${process.pid}');

      // Handle stdin based on whether we have attachments
      if (hasAttachments) {
        // Write JSON message to stdin when attachments are present
        final message = Message(text: text, attachments: attachments);
        final messageJson = jsonEncode(message.toClaudeJson());
        print('[ClaudeClient] Writing JSON to stdin: $messageJson');
        process.stdin.writeln(messageJson);
        await process.stdin.flush();
        await process.stdin.close();
        print('[ClaudeClient] Closed stdin after writing JSON');
      } else {
        // Close stdin immediately since we're passing the message as a CLI argument
        await process.stdin.close();
        print('[ClaudeClient] Closed stdin');
      }

      // Create assistant message for streaming responses
      final assistantId = DateTime.now().millisecondsSinceEpoch.toString();
      List<ClaudeResponse> accumulatedResponses = [];
      bool hasStartedStreaming = false;

      // Buffer for incomplete JSON lines
      final buffer = StringBuffer();

      // Listen directly to stdout
      final stdoutCompleter = Completer<void>();
      process.stdout
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              // Check if aborting
              if (_isAborting) {
                print('[ClaudeClient] Ignoring chunk due to abort');
                return;
              }

              buffer.write(chunk);
              final lines = buffer.toString().split('\n');

              // Keep the last incomplete line in the buffer
              if (lines.isNotEmpty && !chunk.endsWith('\n')) {
                buffer.clear();
                buffer.write(lines.last);
                lines.removeLast();
              } else {
                buffer.clear();
              }

              for (final line in lines) {
                if (line.trim().isEmpty) continue;

                try {
                  final response = _decoder.decodeSingle(line);
                  if (response != null) {
                    accumulatedResponses.add(response);

                    // Extract session_id from responses (not uuid!)
                    // Claude returns session_id for continuation, not uuid
                    if (response.rawData?['session_id'] != null) {
                      _latestConversationUuid = response.rawData!['session_id'] as String;
                      print('[ClaudeClient] Updated session_id for continuation: $_latestConversationUuid');
                    }
                    // Also check for conversation_id in MetaResponse
                    if (response is MetaResponse && response.conversationId != null) {
                      _latestConversationUuid = response.conversationId;
                      print('[ClaudeClient] Updated conversation UUID from MetaResponse: $_latestConversationUuid');
                    }

                    if (response is TextResponse) {
                      if (!hasStartedStreaming) {
                        // Add initial assistant message
                        hasStartedStreaming = true;
                        final assistantMessage = ConversationMessage.assistant(
                          id: assistantId,
                          responses: accumulatedResponses,
                          isStreaming: true,
                        );
                        _updateConversation(_currentConversation.addMessage(assistantMessage));
                      } else {
                        // Update existing assistant message
                        final updatedMessage = ConversationMessage.assistant(
                          id: assistantId,
                          responses: accumulatedResponses,
                          isStreaming: true,
                        );
                        _updateConversation(_currentConversation.updateLastMessage(updatedMessage));
                      }
                    } else if (response is ToolUseResponse || response is ToolResultResponse) {
                      if (response is ToolUseResponse) {
                        print('[ClaudeClient] ========================================');
                        print('[ClaudeClient] TOOL USE RESPONSE');
                        print('[ClaudeClient] Tool: ${response.toolName}');
                        print('[ClaudeClient] Tool Use ID: ${response.toolUseId}');
                        print('[ClaudeClient] Parameters: ${response.parameters}');
                        print('[ClaudeClient] ========================================');
                      } else if (response is ToolResultResponse) {
                        print('[ClaudeClient] ========================================');
                        print('[ClaudeClient] TOOL RESULT RESPONSE');
                        print('[ClaudeClient] Tool Use ID: ${response.toolUseId}');
                        print('[ClaudeClient] Is Error: ${response.isError}');
                        final content = response.content;
                        print('[ClaudeClient] Content Length: ${content.length} chars');
                        if (content.isNotEmpty) {
                          final previewLength = content.length > 100 ? 100 : content.length;
                          print('[ClaudeClient] Content Preview: ${content.substring(0, previewLength)}...');
                        }
                        print('[ClaudeClient] ========================================');
                      }

                      // Update message with tool use/result
                      final updatedMessage = ConversationMessage.assistant(
                        id: assistantId,
                        responses: accumulatedResponses,
                        isStreaming: true,
                      );

                      if (hasStartedStreaming) {
                        _updateConversation(_currentConversation.updateLastMessage(updatedMessage));
                      } else {
                        hasStartedStreaming = true;
                        _updateConversation(_currentConversation.addMessage(updatedMessage));
                      }
                    } else if (response is CompletionResponse) {
                      print('[ClaudeClient] ========================================');
                      print('[ClaudeClient] COMPLETION RESPONSE');
                      print('[ClaudeClient] Stop Reason: ${response.stopReason}');
                      print('[ClaudeClient] Input Tokens: ${response.inputTokens}');
                      print('[ClaudeClient] Output Tokens: ${response.outputTokens}');
                      print('[ClaudeClient] Session ID: $sessionId');
                      print('[ClaudeClient] Total responses accumulated: ${accumulatedResponses.length}');
                      print('[ClaudeClient] ========================================');

                      // Final update with completion
                      final finalMessage = ConversationMessage.assistant(
                        id: assistantId,
                        responses: accumulatedResponses,
                        isStreaming: false,
                        isComplete: true,
                      );

                      // Update token counts
                      final updatedConversation = _currentConversation
                          .updateLastMessage(finalMessage)
                          .withState(ConversationState.idle)
                          .copyWith(
                            totalInputTokens: _currentConversation.totalInputTokens + (response.inputTokens ?? 0),
                            totalOutputTokens: _currentConversation.totalOutputTokens + (response.outputTokens ?? 0),
                          );

                      _updateConversation(updatedConversation);

                      // Clear active process BEFORE notifying turn complete
                      // so that inbox processing can start the next message
                      _activeProcess = null;

                      // Notify listeners that the turn is complete
                      _turnCompleteController.add(null);
                    } else if (response is ErrorResponse) {
                      print('[ClaudeClient] Error: ${response.error}');

                      final errorMessage = ConversationMessage.assistant(
                        id: assistantId,
                        responses: accumulatedResponses,
                        isStreaming: false,
                        isComplete: true,
                      ).copyWith(error: response.error);

                      if (hasStartedStreaming) {
                        _updateConversation(
                          _currentConversation.updateLastMessage(errorMessage).withError(response.error),
                        );
                      } else {
                        _updateConversation(_currentConversation.addMessage(errorMessage).withError(response.error));
                      }

                      // Clear process and notify on error too
                      _activeProcess = null;
                      _turnCompleteController.add(null);
                    } else {
                      // For any other response type (MetaResponse, StatusResponse, etc.)
                      // Just accumulate it but don't update UI yet
                      // The responses will be shown when we get a TextResponse or CompletionResponse
                    }
                  }
                } catch (e) {
                  print('[ClaudeClient] Parse error: $e');
                }
              }
            },
            onDone: () {
              print('[ClaudeClient] stdout closed');
              stdoutCompleter.complete();
            },
            onError: (error) {
              print('[ClaudeClient] stdout error: $error');
              stdoutCompleter.completeError(error);
            },
          );

      // Listen to stderr
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.isNotEmpty) {
          print('[ClaudeClient] CLI Error: $line');
          accumulatedResponses.add(
            ErrorResponse(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              timestamp: DateTime.now(),
              error: 'CLI Error',
              details: line,
            ),
          );
        }
      });

      // Wait for stdout to complete
      await stdoutCompleter.future;

      // Wait for process to exit
      print('[ClaudeClient] Waiting for process to exit...');
      final exitCode = await process.exitCode;
      print('[ClaudeClient] Process exited with code: $exitCode');

      // Clear active process reference
      _activeProcess = null;

      // Mark that we've sent at least one message
      if (_isFirstMessage) {
        print('[ClaudeClient] Marking first message as sent');
        _isFirstMessage = false;
      }

      // Ensure we're back to idle state
      if (_currentConversation.state != ConversationState.idle &&
          _currentConversation.state != ConversationState.error) {
        print('[ClaudeClient] Setting conversation state back to idle');
        _updateConversation(_currentConversation.withState(ConversationState.idle));
      }
    } catch (e, stackTrace) {
      print('[ClaudeClient] ERROR: $e');
      print('[ClaudeClient] Stack trace: $stackTrace');
      _updateConversation(_currentConversation.withError('Failed to send message: $e'));
    }
  }

  @override
  Future<void> abort() async {
    if (_activeProcess == null) {
      print('[ClaudeClient] No active process to abort');
      return;
    }

    print('[ClaudeClient] Aborting active process (PID: ${_activeProcess!.pid})');
    _isAborting = true;

    try {
      // Try graceful termination first (SIGTERM)
      _activeProcess!.kill(ProcessSignal.sigterm);

      // Wait up to 2 seconds for graceful shutdown
      final terminated = await _activeProcess!.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          // Force kill if graceful shutdown fails
          print('[ClaudeClient] Graceful shutdown timed out, force killing process');
          _activeProcess!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      print('[ClaudeClient] Process terminated with exit code: $terminated');

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
      print('[ClaudeClient] Error aborting process: $e');
      _updateConversation(_currentConversation.withError('Failed to abort: $e'));
    } finally {
      _activeProcess = null;
      _isAborting = false;
    }
  }

  Future<void> clearConversation() async {
    _updateConversation(Conversation.empty());
    // Reset to first message for new conversation
    _isFirstMessage = true;
    _latestConversationUuid = null;
  }

  @override
  Future<void> close() async {
    print('[ClaudeClient] VERBOSE: ========================================');
    print('[ClaudeClient] VERBOSE: Closing ClaudeClient');
    print('[ClaudeClient] VERBOSE: Session ID: $sessionId');
    print('[ClaudeClient] VERBOSE: MCP servers to stop: ${mcpServers.length}');

    // Stop all MCP servers
    if (mcpServers.isNotEmpty) {
      for (int i = 0; i < mcpServers.length; i++) {
        final server = mcpServers[i];
        print('[ClaudeClient] VERBOSE: Stopping server ${i + 1}/${mcpServers.length}: ${server.name}');
        print('[ClaudeClient] VERBOSE: Server ${server.name} isRunning: ${server.isRunning}');
        try {
          await server.stop();
          print('[ClaudeClient] VERBOSE: ✓ ${server.name} stopped');
        } catch (e) {
          print('[ClaudeClient] VERBOSE: ❌ Failed to stop ${server.name}: $e');
        }
      }
    } else {
      print('[ClaudeClient] VERBOSE: No MCP servers to stop');
    }

    // Cancel inbox subscription
    await _inboxSubscription?.cancel();
    _inboxSubscription = null;

    // Close streams
    print('[ClaudeClient] VERBOSE: Closing streams...');
    await _conversationController.close();
    await _turnCompleteController.close();
    print('[ClaudeClient] VERBOSE: Streams closed');

    _isInitialized = false;
    print('[ClaudeClient] VERBOSE: Marked as not initialized');
    print('[ClaudeClient] VERBOSE: ClaudeClient closed');
    print('[ClaudeClient] VERBOSE: ========================================');
  }

  Future<void> restart() async {
    await close();
    _isFirstMessage = true;
    _latestConversationUuid = null;
  }

  @override
  String get workingDirectory => config.workingDirectory!;
}
