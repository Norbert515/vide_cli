/// Exception hierarchy for claude_api errors.
///
/// This provides a consistent approach to error handling with typed exceptions
/// that allow callers to catch and handle specific error cases.
library;

/// Base exception for all claude_api errors.
///
/// All exceptions in the claude_api package extend this class,
/// allowing callers to catch all claude_api errors with a single catch clause.
class ClaudeApiException implements Exception {
  /// A human-readable error message.
  final String message;

  /// The underlying error that caused this exception, if any.
  final Object? cause;

  /// The stack trace at the point where the error occurred.
  final StackTrace? stackTrace;

  /// Creates a new [ClaudeApiException].
  ClaudeApiException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    final buffer = StringBuffer('ClaudeApiException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when the Claude CLI process fails to start.
///
/// This can happen when:
/// - The `claude` command is not found in the PATH
/// - The process fails to start due to permission issues
/// - Invalid arguments are passed to the process
class ProcessStartException extends ClaudeApiException {
  /// Creates a new [ProcessStartException].
  ProcessStartException(super.message, {super.cause, super.stackTrace});

  @override
  String toString() {
    final buffer = StringBuffer('ProcessStartException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when the control protocol encounters an error.
///
/// This can happen when:
/// - The control protocol connection fails
/// - A protocol message is invalid
/// - The control protocol times out
class ControlProtocolException extends ClaudeApiException {
  /// Creates a new [ControlProtocolException].
  ControlProtocolException(super.message, {super.cause, super.stackTrace});

  @override
  String toString() {
    final buffer = StringBuffer('ControlProtocolException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when response parsing fails.
///
/// This can happen when:
/// - JSON response is malformed
/// - Required fields are missing from the response
/// - Response type is unexpected
class ResponseParsingException extends ClaudeApiException {
  /// The raw response that failed to parse, if available.
  final String? rawResponse;

  /// Creates a new [ResponseParsingException].
  ResponseParsingException(
    super.message, {
    this.rawResponse,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ResponseParsingException: $message');
    if (rawResponse != null) {
      buffer.write('\nRaw response: $rawResponse');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when loading a conversation from history fails.
///
/// This can happen when:
/// - The conversation file is missing or corrupted
/// - The conversation format is invalid
/// - File system errors occur
class ConversationLoadException extends ClaudeApiException {
  /// The session ID of the conversation that failed to load, if known.
  final String? sessionId;

  /// Creates a new [ConversationLoadException].
  ConversationLoadException(
    super.message, {
    this.sessionId,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ConversationLoadException: $message');
    if (sessionId != null) {
      buffer.write('\nSession ID: $sessionId');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
