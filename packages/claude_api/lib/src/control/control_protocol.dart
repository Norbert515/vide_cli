/// Control Protocol Handler for Claude Code SDK
///
/// This manages the bidirectional control protocol between the SDK
/// and the Claude CLI, enabling hooks and permission callbacks.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'control_types.dart';
import 'control_messages.dart';

/// Manages the control protocol for a Claude CLI session
class ControlProtocol {
  final Process _process;

  /// Registered hook callbacks by callback ID
  final Map<String, HookCallback> _hookCallbacks = {};

  /// Permission callback (optional)
  CanUseToolCallback? _canUseToolCallback;

  /// In-process MCP servers for SDK MCP support
  final Map<String, dynamic> _sdkMcpServers = {};

  /// Pending control requests waiting for responses
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  /// Next callback ID for hook registration
  int _nextCallbackId = 0;

  /// Next request ID for outgoing requests
  int _nextRequestId = 0;

  /// Stream controller for non-control messages
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of regular messages (non-control)
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Buffer for incomplete JSON lines
  final _buffer = StringBuffer();

  /// Whether the protocol has been initialized
  bool _initialized = false;

  /// Subscription to stdout
  StreamSubscription<String>? _stdoutSubscription;

  ControlProtocol(this._process);

  /// Initialize the control protocol with hooks
  Future<void> initialize({
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
  }) async {
    if (_initialized) {
      throw StateError('Control protocol already initialized');
    }

    _canUseToolCallback = canUseTool;

    // Start listening to stdout
    _startListening();

    // Build hooks configuration
    final hooksConfig = <String, List<Map<String, dynamic>>>{};

    if (hooks != null) {
      for (final entry in hooks.entries) {
        final eventName = entry.key.value;
        final matchers = entry.value;

        hooksConfig[eventName] = matchers.map((m) {
          final callbackId = 'hook_${_nextCallbackId++}';
          _hookCallbacks[callbackId] = m.callback;
          return {
            'matcher': m.matcher,
            'callback_id': callbackId,
            'timeout': m.timeout,
          };
        }).toList();
      }
    }

    // Send initialize request
    if (hooksConfig.isNotEmpty || canUseTool != null) {
      await _sendControlRequest('initialize', {'hooks': hooksConfig});
    }

    _initialized = true;
  }

  /// Start listening to stdout for messages
  void _startListening() {
    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .listen(_handleStdoutChunk);
  }

  /// Handle a chunk of stdout data
  void _handleStdoutChunk(String chunk) {
    _buffer.write(chunk);
    final lines = _buffer.toString().split('\n');

    // Keep incomplete line in buffer
    if (lines.isNotEmpty && !chunk.endsWith('\n')) {
      _buffer.clear();
      _buffer.write(lines.last);
      lines.removeLast();
    } else {
      _buffer.clear();
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      _handleLine(line);
    }
  }

  /// Handle a single JSON line from stdout
  void _handleLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'control_request') {
        _handleControlRequest(json);
      } else if (type == 'control_response') {
        _handleControlResponse(json);
      } else {
        // Regular message - pass to message stream
        _messageController.add(json);
      }
    } catch (e) {
      // Not valid JSON, pass as-is wrapped in a message
      _messageController.add({'type': 'raw', 'content': line});
    }
  }

  /// Handle an incoming control request from CLI
  Future<void> _handleControlRequest(Map<String, dynamic> json) async {
    final request = ControlRequest.fromJson(json);

    try {
      Map<String, dynamic> response;

      switch (request) {
        case CanUseToolRequest():
          response = await _handleCanUseTool(request);
        case HookCallbackRequest():
          response = await _handleHookCallback(request);
        case McpMessageRequest():
          response = await _handleMcpMessage(request);
        case UnknownControlRequest():
          response = {}; // Allow by default for unknown requests
      }

      _sendControlResponse(request.requestId, response);
    } catch (e) {
      _sendControlError(request.requestId, e.toString());
    }
  }

  /// Handle a can_use_tool request
  Future<Map<String, dynamic>> _handleCanUseTool(CanUseToolRequest request) async {
    if (_canUseToolCallback == null) {
      // No callback registered, allow by default
      return {
        'behavior': 'allow',
        'updatedInput': request.input,
      };
    }

    final result = await _canUseToolCallback!(
      request.toolName,
      request.input,
      request.context,
    );

    // Build response - always include updatedInput for allow responses
    final json = result.toJson();
    if (result is PermissionResultAllow && json['updatedInput'] == null) {
      json['updatedInput'] = request.input;
    }
    return json;
  }

  /// Handle a hook_callback request
  Future<Map<String, dynamic>> _handleHookCallback(HookCallbackRequest request) async {
    final callback = _hookCallbacks[request.callbackId];

    if (callback == null) {
      // No callback registered for this ID, allow by default
      return const HookOutput().toJson();
    }

    final result = await callback(request.input, request.toolUseId);
    return result.toJson();
  }

  /// Handle an mcp_message request
  Future<Map<String, dynamic>> _handleMcpMessage(McpMessageRequest request) async {
    final server = _sdkMcpServers[request.serverName];

    if (server == null) {
      throw Exception('Unknown MCP server: ${request.serverName}');
    }

    // Route JSONRPC message to the MCP server
    // This is a simplified implementation - full implementation would
    // need to handle all MCP protocol methods
    final method = request.message['method'] as String?;

    switch (method) {
      case 'initialize':
        return {
          'jsonrpc': '2.0',
          'id': request.message['id'],
          'result': {
            'protocolVersion': '2024-11-05',
            'capabilities': {'tools': {}},
            'serverInfo': {'name': request.serverName, 'version': '1.0.0'},
          },
        };
      case 'tools/list':
        // Would need to get tools from the server
        return {
          'jsonrpc': '2.0',
          'id': request.message['id'],
          'result': {'tools': []},
        };
      case 'tools/call':
        // Would need to call the tool on the server
        return {
          'jsonrpc': '2.0',
          'id': request.message['id'],
          'result': {'content': [{'type': 'text', 'text': 'Not implemented'}]},
        };
      case 'notifications/initialized':
        return {};
      default:
        throw Exception('Unknown MCP method: $method');
    }
  }

  /// Handle an incoming control response
  void _handleControlResponse(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>?;
    if (response == null) return;

    final requestId = response['request_id'] as String?;
    if (requestId == null) return;

    final completer = _pendingRequests.remove(requestId);
    if (completer == null) return;

    final subtype = response['subtype'] as String?;
    if (subtype == 'error') {
      completer.completeError(Exception(response['error']));
    } else {
      completer.complete(response['response'] as Map<String, dynamic>? ?? {});
    }
  }

  /// Send a control request to CLI and wait for response
  Future<Map<String, dynamic>> _sendControlRequest(
    String subtype,
    Map<String, dynamic> data,
  ) async {
    final requestId = 'req_${_nextRequestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    final request = OutgoingControlRequest(
      requestId: requestId,
      subtype: subtype,
      data: data,
    );

    _writeToStdin(request.toJson());

    return completer.future;
  }

  /// Send a control response to CLI
  void _sendControlResponse(String requestId, Map<String, dynamic> response) {
    final controlResponse = ControlResponse.success(requestId, response);
    _writeToStdin(controlResponse.toJson());
  }

  /// Send a control error response to CLI
  void _sendControlError(String requestId, String error) {
    final controlResponse = ControlResponse.error(requestId, error);
    _writeToStdin(controlResponse.toJson());
  }

  /// Write JSON to stdin
  void _writeToStdin(Map<String, dynamic> json) {
    final line = jsonEncode(json);
    _process.stdin.writeln(line);
  }

  /// Send a user message to the CLI
  void sendUserMessage(String content) {
    _writeToStdin({
      'type': 'user',
      'message': {
        'role': 'user',
        'content': content,
      },
    });
  }

  /// Send a user message with attachments
  void sendUserMessageWithContent(List<Map<String, dynamic>> content) {
    _writeToStdin({
      'type': 'user',
      'message': {
        'role': 'user',
        'content': content,
      },
    });
  }

  /// Interrupt the current execution
  Future<void> interrupt() async {
    await _sendControlRequest('interrupt', {});
  }

  /// Set the permission mode
  Future<void> setPermissionMode(String mode) async {
    await _sendControlRequest('set_permission_mode', {'mode': mode});
  }

  /// Rewind files to a previous state
  Future<void> rewindFiles(String userMessageId) async {
    await _sendControlRequest('rewind_files', {'user_message_id': userMessageId});
  }

  /// Register an in-process MCP server
  void registerSdkMcpServer(String name, dynamic server) {
    _sdkMcpServers[name] = server;
  }

  /// Close the protocol handler
  Future<void> close() async {
    await _stdoutSubscription?.cancel();
    await _messageController.close();
    _hookCallbacks.clear();
    _pendingRequests.clear();
    _sdkMcpServers.clear();
  }
}
