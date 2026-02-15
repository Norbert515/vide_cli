import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/json_rpc_message.dart';

/// Persistent subprocess transport for the Codex app-server.
///
/// Manages a long-lived `codex app-server` process, communicating via
/// JSON-RPC over JSONL on stdin/stdout. Handles:
/// - Request/response correlation (auto-increments `id`, matches responses)
/// - Routing incoming messages to typed streams
/// - Subprocess lifecycle (start/close)
class CodexTransport {
  Process? _process;
  int _nextId = 0;
  bool _closed = false;

  /// Pending requests waiting for a response, keyed by request id.
  final _pendingRequests = <dynamic, Completer<JsonRpcResponse>>{};

  /// Server notifications (no id, no response expected).
  final _notificationController =
      StreamController<JsonRpcNotification>.broadcast();

  /// Server requests that need a client response (e.g., approvals).
  final _serverRequestController =
      StreamController<JsonRpcRequest>.broadcast();

  /// Raw stderr output for error diagnostics.
  final _stderrBuffer = StringBuffer();

  /// Whether the transport is currently connected to a subprocess.
  bool get isRunning => _process != null && !_closed;

  /// Server notifications stream.
  Stream<JsonRpcNotification> get notifications =>
      _notificationController.stream;

  /// Server requests stream (approval requests).
  Stream<JsonRpcRequest> get serverRequests =>
      _serverRequestController.stream;

  /// Start the `codex app-server` subprocess.
  Future<void> start({
    String? workingDirectory,
    List<String> extraArgs = const [],
  }) async {
    if (_closed) {
      throw StateError('Transport has been closed');
    }
    if (_process != null) {
      throw StateError('Transport already started');
    }

    final args = ['app-server', ...extraArgs];

    _process = await Process.start(
      'codex',
      args,
      workingDirectory: workingDirectory,
      environment: Platform.environment,
    );

    _process!.stdout.transform(utf8.decoder).listen(
      _onStdoutData,
      onDone: _onProcessDone,
    );

    _process!.stderr.transform(utf8.decoder).listen((chunk) {
      _stderrBuffer.write(chunk);
    });
  }

  /// Send a JSON-RPC request and wait for the correlated response.
  Future<JsonRpcResponse> sendRequest(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    _ensureRunning();

    final id = _nextId++;
    final completer = Completer<JsonRpcResponse>();
    _pendingRequests[id] = completer;

    final request = <String, dynamic>{
      'method': method,
      'id': id,
      if (params != null) 'params': params,
    };

    _writeLine(jsonEncode(request));
    return completer.future;
  }

  /// Send a JSON-RPC notification (fire-and-forget, no response expected).
  void sendNotification(String method, [Map<String, dynamic>? params]) {
    _ensureRunning();

    final notification = <String, dynamic>{
      'method': method,
      if (params != null) 'params': params,
    };

    _writeLine(jsonEncode(notification));
  }

  /// Respond to a server-initiated request (e.g., approval decisions).
  void respondToRequest(dynamic requestId, Map<String, dynamic> result) {
    _ensureRunning();

    final response = <String, dynamic>{
      'id': requestId,
      'result': result,
    };

    _writeLine(jsonEncode(response));
  }

  /// Close the transport and kill the subprocess.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    // Complete all pending requests with an error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Transport closed while request was pending'),
        );
      }
    }
    _pendingRequests.clear();

    _process?.kill(ProcessSignal.sigterm);
    _process = null;

    await _notificationController.close();
    await _serverRequestController.close();
  }

  // --------------------------------------------------------------------------
  // Private
  // --------------------------------------------------------------------------

  final _lineBuffer = StringBuffer();

  void _onStdoutData(String chunk) {
    _lineBuffer.write(chunk);
    final content = _lineBuffer.toString();
    final lines = content.split('\n');

    // Keep the last potentially incomplete line
    _lineBuffer.clear();
    if (!content.endsWith('\n') && lines.isNotEmpty) {
      _lineBuffer.write(lines.removeLast());
    } else if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      _routeMessage(trimmed);
    }
  }

  void _routeMessage(String line) {
    final message = JsonRpcMessage.parseLine(line);
    if (message == null) return;

    switch (message) {
      case JsonRpcResponse response:
        final completer = _pendingRequests.remove(response.id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(response);
        }
      case JsonRpcRequest request:
        if (!_serverRequestController.isClosed) {
          _serverRequestController.add(request);
        }
      case JsonRpcNotification notification:
        if (!_notificationController.isClosed) {
          _notificationController.add(notification);
        }
    }
  }

  void _onProcessDone() {
    if (_closed) return;

    // Complete all pending requests with an error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        final stderr = _stderrBuffer.toString();
        completer.completeError(
          StateError(
            'codex app-server process terminated unexpectedly'
            '${stderr.isNotEmpty ? ': $stderr' : ''}',
          ),
        );
      }
    }
    _pendingRequests.clear();
    _process = null;
  }

  void _writeLine(String json) {
    _process!.stdin.writeln(json);
  }

  void _ensureRunning() {
    if (_closed) throw StateError('Transport has been closed');
    if (_process == null) throw StateError('Transport not started');
  }
}
