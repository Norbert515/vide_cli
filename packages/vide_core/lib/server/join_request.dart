/// Join request types for the embedded server.
///
/// These types are used for managing client connection approval flow.

/// A request from a remote client to join the session.
final class JoinRequest {
  /// Unique identifier for this join request.
  final String id;

  /// The remote address of the requesting client.
  final String remoteAddress;

  /// When the request was received.
  final DateTime requestedAt;

  const JoinRequest({
    required this.id,
    required this.remoteAddress,
    required this.requestedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remote-address': remoteAddress,
        'requested-at': requestedAt.toIso8601String(),
      };

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] as String,
      remoteAddress: json['remote-address'] as String,
      requestedAt: DateTime.parse(json['requested-at'] as String),
    );
  }
}

/// Response to a join request.
enum JoinResponse {
  /// Allow full interaction (can send messages and respond to permissions).
  allow,

  /// Allow read-only access (can only view events).
  allowReadOnly,

  /// Deny access and close the connection.
  deny,
}
