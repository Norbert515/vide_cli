/// Client-to-server messages for vide sessions.

/// Base class for all messages sent from client to server.
sealed class ClientMessage {
  const ClientMessage();

  Map<String, dynamic> toJson();

  static ClientMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'user-message' => SendUserMessage.fromJson(json),
      'permission-response' => PermissionResponse.fromJson(json),
      'abort' => AbortRequest.fromJson(json),
      _ => throw ArgumentError('Unknown message type: $type'),
    };
  }
}

/// Send a user message to the session.
final class SendUserMessage extends ClientMessage {
  final String content;
  final String? model;

  const SendUserMessage({
    required this.content,
    this.model,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'user-message',
        'content': content,
        if (model != null) 'model': model,
      };

  factory SendUserMessage.fromJson(Map<String, dynamic> json) {
    return SendUserMessage(
      content: json['content'] as String,
      model: json['model'] as String?,
    );
  }
}

/// Respond to a permission request.
final class PermissionResponse extends ClientMessage {
  final String requestId;
  final bool allow;

  const PermissionResponse({
    required this.requestId,
    required this.allow,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'permission-response',
        'request-id': requestId,
        'allow': allow,
      };

  factory PermissionResponse.fromJson(Map<String, dynamic> json) {
    return PermissionResponse(
      requestId: json['request-id'] as String,
      allow: json['allow'] as bool,
    );
  }
}

/// Abort all active agents in the session.
final class AbortRequest extends ClientMessage {
  const AbortRequest();

  @override
  Map<String, dynamic> toJson() => {
        'type': 'abort',
      };

  factory AbortRequest.fromJson(Map<String, dynamic> json) {
    return const AbortRequest();
  }
}
