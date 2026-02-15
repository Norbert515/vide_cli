import 'dart:convert';

/// JSON-RPC message types for the Codex app-server protocol.
///
/// The app-server communicates via JSONL (one JSON object per line) over
/// stdin/stdout. Messages follow JSON-RPC 2.0 conventions but omit the
/// `"jsonrpc":"2.0"` header.
///
/// Three message patterns:
/// - **Notifications** (server→client): no `id`, just `method` + `params`
/// - **Requests** (bidirectional): has `id` + `method` + `params`, expects a response
/// - **Responses**: has `id` + `result`/`error`, correlates to a prior request
sealed class JsonRpcMessage {
  const JsonRpcMessage();

  factory JsonRpcMessage.fromJson(Map<String, dynamic> json) {
    final hasId = json.containsKey('id');
    final hasMethod = json.containsKey('method');
    final hasResult = json.containsKey('result');
    final hasError = json.containsKey('error');

    if (hasId && (hasResult || hasError) && !hasMethod) {
      // Response to a request we sent
      return JsonRpcResponse.fromJson(json);
    }

    if (hasId && hasMethod) {
      // Request from server (e.g., approval requests)
      return JsonRpcRequest.fromJson(json);
    }

    if (hasMethod && !hasId) {
      // Notification from server
      return JsonRpcNotification.fromJson(json);
    }

    // Error response has id + error but no method
    if (hasId && hasError) {
      return JsonRpcResponse.fromJson(json);
    }

    return JsonRpcNotification(
      method: json['method'] as String? ?? 'unknown',
      params: json,
    );
  }

  /// Parse a single JSONL line into a [JsonRpcMessage].
  /// Returns null if the line is empty or cannot be parsed.
  static JsonRpcMessage? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      return JsonRpcMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

/// A notification from the server (no response expected).
///
/// Examples: `turn/started`, `item/completed`, `item/agentMessage/delta`
class JsonRpcNotification extends JsonRpcMessage {
  final String method;
  final Map<String, dynamic> params;

  const JsonRpcNotification({
    required this.method,
    required this.params,
  });

  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) {
    return JsonRpcNotification(
      method: json['method'] as String? ?? '',
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  String toString() => 'JsonRpcNotification(method: $method)';
}

/// A request from the server that requires a response from the client.
///
/// Used for approval requests: `item/commandExecution/requestApproval`,
/// `item/fileChange/requestApproval`, `item/tool/requestUserInput`.
class JsonRpcRequest extends JsonRpcMessage {
  /// Request ID (String or int). Must be echoed back in the response.
  final dynamic id;
  final String method;
  final Map<String, dynamic> params;

  const JsonRpcRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return JsonRpcRequest(
      id: json['id'],
      method: json['method'] as String? ?? '',
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  String toString() => 'JsonRpcRequest(id: $id, method: $method)';
}

/// A response to a request we sent to the server.
class JsonRpcResponse extends JsonRpcMessage {
  /// Matches the `id` of the request this responds to.
  final dynamic id;
  final Map<String, dynamic>? result;
  final JsonRpcError? error;

  const JsonRpcResponse({
    required this.id,
    this.result,
    this.error,
  });

  bool get isError => error != null;

  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    final errorData = json['error'];
    JsonRpcError? error;
    if (errorData is Map<String, dynamic>) {
      error = JsonRpcError.fromJson(errorData);
    }

    final resultData = json['result'];
    final Map<String, dynamic>? result = resultData is Map
        ? Map<String, dynamic>.from(resultData)
        : null;

    return JsonRpcResponse(
      id: json['id'],
      result: result,
      error: error,
    );
  }

  @override
  String toString() => 'JsonRpcResponse(id: $id, isError: $isError)';
}

/// A JSON-RPC error object.
class JsonRpcError {
  final int code;
  final String message;
  final dynamic data;

  const JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    return JsonRpcError(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? 'Unknown error',
      data: json['data'],
    );
  }

  @override
  String toString() => 'JsonRpcError(code: $code, message: $message)';
}
