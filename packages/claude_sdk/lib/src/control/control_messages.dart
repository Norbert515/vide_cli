/// Control Protocol Messages for Claude Code SDK
///
/// These are the JSON message structures used for bidirectional
/// communication between the SDK and the Claude CLI.

import 'control_types.dart';

/// Base class for control requests from CLI
sealed class ControlRequest {
  final String requestId;

  const ControlRequest({required this.requestId});

  factory ControlRequest.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>;
    final subtype = request['subtype'] as String;
    final requestId = json['request_id'] as String;

    switch (subtype) {
      case 'can_use_tool':
        return CanUseToolRequest.fromJson(json);
      case 'hook_callback':
        return HookCallbackRequest.fromJson(json);
      case 'mcp_message':
        return McpMessageRequest.fromJson(json);
      default:
        return UnknownControlRequest(
          requestId: requestId,
          subtype: subtype,
          data: request,
        );
    }
  }
}

/// Permission request from CLI when Claude wants to use a tool
class CanUseToolRequest extends ControlRequest {
  final String toolName;
  final Map<String, dynamic> input;
  final List<String>? permissionSuggestions;
  final String? blockedPath;

  const CanUseToolRequest({
    required super.requestId,
    required this.toolName,
    required this.input,
    this.permissionSuggestions,
    this.blockedPath,
  });

  factory CanUseToolRequest.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>;
    return CanUseToolRequest(
      requestId: json['request_id'] as String,
      toolName: request['tool_name'] as String? ?? '',
      input: (request['input'] as Map<String, dynamic>?) ?? {},
      permissionSuggestions:
          (request['permission_suggestions'] as List<dynamic>?)?.cast<String>(),
      blockedPath: request['blocked_path'] as String?,
    );
  }

  ToolPermissionContext get context => ToolPermissionContext(
    permissionSuggestions: permissionSuggestions,
    blockedPath: blockedPath,
  );
}

/// Hook callback request from CLI
class HookCallbackRequest extends ControlRequest {
  final String callbackId;
  final String? toolUseId;
  final HookInput input;

  const HookCallbackRequest({
    required super.requestId,
    required this.callbackId,
    this.toolUseId,
    required this.input,
  });

  factory HookCallbackRequest.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>;
    final inputData = request['input'] as Map<String, dynamic>? ?? {};

    return HookCallbackRequest(
      requestId: json['request_id'] as String,
      callbackId: request['callback_id'] as String? ?? '',
      toolUseId: request['tool_use_id'] as String?,
      input: HookInput.fromJson(inputData),
    );
  }
}

/// MCP message request from CLI for in-process MCP servers
class McpMessageRequest extends ControlRequest {
  final String serverName;
  final Map<String, dynamic> message;

  const McpMessageRequest({
    required super.requestId,
    required this.serverName,
    required this.message,
  });

  factory McpMessageRequest.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>;
    return McpMessageRequest(
      requestId: json['request_id'] as String,
      serverName: request['server_name'] as String? ?? '',
      message: (request['message'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Unknown control request for forward compatibility
class UnknownControlRequest extends ControlRequest {
  final String subtype;
  final Map<String, dynamic> data;

  const UnknownControlRequest({
    required super.requestId,
    required this.subtype,
    required this.data,
  });
}

/// Control response sent from SDK to CLI
class ControlResponse {
  final String requestId;
  final bool success;
  final Map<String, dynamic>? response;
  final String? error;

  const ControlResponse({
    required this.requestId,
    required this.success,
    this.response,
    this.error,
  });

  factory ControlResponse.success(
    String requestId,
    Map<String, dynamic> response,
  ) {
    return ControlResponse(
      requestId: requestId,
      success: true,
      response: response,
    );
  }

  factory ControlResponse.error(String requestId, String error) {
    return ControlResponse(requestId: requestId, success: false, error: error);
  }

  Map<String, dynamic> toJson() => {
    'type': 'control_response',
    'response': {
      'subtype': success ? 'success' : 'error',
      'request_id': requestId,
      if (success && response != null) 'response': response,
      if (!success && error != null) 'error': error,
    },
  };
}

/// Control request sent from SDK to CLI
class OutgoingControlRequest {
  final String requestId;
  final String subtype;
  final Map<String, dynamic> data;

  const OutgoingControlRequest({
    required this.requestId,
    required this.subtype,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'type': 'control_request',
    'request_id': requestId,
    'request': {'subtype': subtype, ...data},
  };
}
