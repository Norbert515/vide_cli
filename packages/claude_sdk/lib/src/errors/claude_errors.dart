/// Exception hierarchy for claude_sdk errors.
///
/// This provides a consistent approach to error handling with typed exceptions
/// that allow callers to catch and handle specific error cases.
///
/// ## Exception Hierarchy
///
/// ```
/// ClaudeApiException (base)
/// ├── CliNotFoundException - Claude CLI not installed
/// ├── ProcessException - CLI process failures (with exit code, stderr)
/// │   └── ProcessStartException - Process failed to start
/// ├── ControlProtocolException - Protocol connection/message errors
/// ├── ResponseParsingException - JSON parsing failures
/// ├── MessageParseException - Message-level parsing failures
/// ├── ConversationLoadException - History loading failures
/// ├── ApiException - API-level errors (with error type, status code)
/// │   └── RateLimitException - Rate limiting (with retry-after)
/// └── TimeoutException - Operation timeouts
/// ```
///
/// ## Retryable Errors
///
/// Some exceptions are retryable (e.g., rate limits, server errors).
/// Check [ClaudeApiException.isRetryable] to determine if retry is appropriate.
library;

/// Base exception for all claude_sdk errors.
///
/// All exceptions in the claude_sdk package extend this class,
/// allowing callers to catch all claude_sdk errors with a single catch clause.
///
/// Example:
/// ```dart
/// try {
///   await client.sendMessage(message);
/// } on RateLimitException catch (e) {
///   // Wait and retry
///   await Future.delayed(e.retryAfter ?? Duration(seconds: 60));
/// } on CliNotFoundException {
///   print('Please install Claude Code CLI');
/// } on ClaudeApiException catch (e) {
///   // Handle all other SDK errors
///   print('Error: ${e.message}');
/// }
/// ```
class ClaudeApiException implements Exception {
  /// A human-readable error message.
  final String message;

  /// The underlying error that caused this exception, if any.
  final Object? cause;

  /// The stack trace at the point where the error occurred.
  final StackTrace? stackTrace;

  /// Creates a new [ClaudeApiException].
  ClaudeApiException(this.message, {this.cause, this.stackTrace});

  /// Whether this error is potentially retryable.
  ///
  /// Returns `true` for transient errors like rate limits or server errors.
  /// Returns `false` for permanent errors like invalid requests or auth failures.
  bool get isRetryable => false;

  @override
  String toString() {
    final buffer = StringBuffer('ClaudeApiException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when the Claude CLI is not found or not installed.
///
/// This is a specific subtype of connection errors indicating that
/// the `claude` command is not available in the system PATH.
///
/// To resolve this error, install Claude Code CLI:
/// ```bash
/// npm install -g @anthropic-ai/claude-code
/// ```
class CliNotFoundException extends ClaudeApiException {
  /// The path that was searched for the CLI, if known.
  final String? cliPath;

  /// Creates a new [CliNotFoundException].
  CliNotFoundException({
    String message = 'Claude Code CLI not found',
    this.cliPath,
    super.cause,
    super.stackTrace,
  }) : super(message);

  @override
  String toString() {
    final buffer = StringBuffer('CliNotFoundException: $message');
    if (cliPath != null) {
      buffer.write('\nSearched path: $cliPath');
    }
    buffer.write('\nInstall with: npm install -g @anthropic-ai/claude-code');
    return buffer.toString();
  }
}

/// Thrown when a Claude CLI process fails.
///
/// This provides detailed information about process failures including
/// the exit code and stderr output for debugging.
class ProcessException extends ClaudeApiException {
  /// The exit code of the process, if available.
  final int? exitCode;

  /// The stderr output from the process, if available.
  final String? stderr;

  /// Creates a new [ProcessException].
  ProcessException(
    super.message, {
    this.exitCode,
    this.stderr,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ProcessException: $message');
    if (exitCode != null) {
      buffer.write('\nExit code: $exitCode');
    }
    if (stderr != null && stderr!.isNotEmpty) {
      buffer.write('\nStderr: $stderr');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when the Claude CLI process fails to start.
///
/// This can happen when:
/// - The `claude` command is not found in the PATH (see [CliNotFoundException])
/// - The process fails to start due to permission issues
/// - Invalid arguments are passed to the process
class ProcessStartException extends ProcessException {
  /// Creates a new [ProcessStartException].
  ProcessStartException(
    super.message, {
    super.exitCode,
    super.stderr,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ProcessStartException: $message');
    if (exitCode != null) {
      buffer.write('\nExit code: $exitCode');
    }
    if (stderr != null && stderr!.isNotEmpty) {
      buffer.write('\nStderr: $stderr');
    }
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

/// Thrown when unable to parse a message from CLI output.
///
/// This is more specific than [ResponseParsingException] and indicates
/// that a message was received but could not be properly parsed into
/// the expected message structure.
class MessageParseException extends ClaudeApiException {
  /// The raw data that failed to parse, if available.
  final Map<String, dynamic>? data;

  /// Creates a new [MessageParseException].
  MessageParseException(
    super.message, {
    this.data,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('MessageParseException: $message');
    if (data != null) {
      buffer.write('\nData: $data');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Known API error types from the Claude API.
///
/// These match the error types returned by the Claude API.
/// See: https://docs.anthropic.com/en/api/errors
enum ApiErrorType {
  /// Invalid request format or content (400)
  invalidRequest('invalid_request_error'),

  /// Authentication failure (401)
  authentication('authentication_error'),

  /// Insufficient permissions (403)
  permission('permission_error'),

  /// Resource not found (404)
  notFound('not_found_error'),

  /// Request too large (413)
  requestTooLarge('request_too_large'),

  /// Rate limit exceeded (429)
  rateLimit('rate_limit_error'),

  /// Internal server error (500)
  api('api_error'),

  /// API overloaded (529)
  overloaded('overloaded_error'),

  /// Unknown error type
  unknown('unknown');

  /// The string value as returned by the API.
  final String value;

  const ApiErrorType(this.value);

  /// Parse an error type from its string value.
  static ApiErrorType fromString(String? value) {
    if (value == null) return ApiErrorType.unknown;
    return ApiErrorType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ApiErrorType.unknown,
    );
  }
}

/// Thrown when the Claude API returns an error.
///
/// This represents errors from the Claude API itself, including
/// validation errors, authentication failures, and server errors.
///
/// Use [errorType] to determine the category of error and [statusCode]
/// for the HTTP status code.
///
/// Example:
/// ```dart
/// try {
///   await client.sendMessage(message);
/// } on ApiException catch (e) {
///   if (e.isRetryable) {
///     // Retry with exponential backoff
///   } else {
///     // Fail fast - fix the request
///   }
/// }
/// ```
class ApiException extends ClaudeApiException {
  /// The type of API error.
  final ApiErrorType errorType;

  /// The HTTP status code, if available.
  final int? statusCode;

  /// The unique request ID for debugging, if available.
  ///
  /// Include this when contacting support.
  final String? requestId;

  /// Creates a new [ApiException].
  ApiException(
    super.message, {
    this.errorType = ApiErrorType.unknown,
    this.statusCode,
    this.requestId,
    super.cause,
    super.stackTrace,
  });

  /// Creates an [ApiException] from an API error response.
  factory ApiException.fromResponse({
    required String message,
    String? errorType,
    int? statusCode,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final type = ApiErrorType.fromString(errorType);

    // Return specialized exception for rate limits
    if (type == ApiErrorType.rateLimit) {
      return RateLimitException(
        message,
        statusCode: statusCode,
        requestId: requestId,
        cause: cause,
        stackTrace: stackTrace,
      );
    }

    return ApiException(
      message,
      errorType: type,
      statusCode: statusCode,
      requestId: requestId,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case ApiErrorType.rateLimit:
      case ApiErrorType.api:
      case ApiErrorType.overloaded:
        return true;
      case ApiErrorType.invalidRequest:
      case ApiErrorType.authentication:
      case ApiErrorType.permission:
      case ApiErrorType.notFound:
      case ApiErrorType.requestTooLarge:
      case ApiErrorType.unknown:
        return false;
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('ApiException: $message');
    buffer.write('\nError type: ${errorType.value}');
    if (statusCode != null) {
      buffer.write('\nStatus code: $statusCode');
    }
    if (requestId != null) {
      buffer.write('\nRequest ID: $requestId');
    }
    if (isRetryable) {
      buffer.write('\n(This error is retryable)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when the API rate limit is exceeded.
///
/// This is a specialized [ApiException] that includes information about
/// when to retry the request.
///
/// Example:
/// ```dart
/// try {
///   await client.sendMessage(message);
/// } on RateLimitException catch (e) {
///   final waitTime = e.retryAfter ?? Duration(seconds: 60);
///   print('Rate limited. Retrying in ${waitTime.inSeconds}s');
///   await Future.delayed(waitTime);
///   // Retry the request
/// }
/// ```
class RateLimitException extends ApiException {
  /// The duration to wait before retrying, if provided by the API.
  final Duration? retryAfter;

  /// Creates a new [RateLimitException].
  RateLimitException(
    super.message, {
    this.retryAfter,
    super.statusCode,
    super.requestId,
    super.cause,
    super.stackTrace,
  }) : super(errorType: ApiErrorType.rateLimit);

  @override
  bool get isRetryable => true;

  @override
  String toString() {
    final buffer = StringBuffer('RateLimitException: $message');
    if (retryAfter != null) {
      buffer.write('\nRetry after: ${retryAfter!.inSeconds}s');
    }
    if (statusCode != null) {
      buffer.write('\nStatus code: $statusCode');
    }
    if (requestId != null) {
      buffer.write('\nRequest ID: $requestId');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when an operation times out.
///
/// This can happen when:
/// - Control protocol request times out
/// - API request times out
/// - MCP server doesn't respond in time
class ClaudeTimeoutException extends ClaudeApiException {
  /// The operation that timed out.
  final String? operation;

  /// The timeout duration that was exceeded.
  final Duration? timeout;

  /// Creates a new [ClaudeTimeoutException].
  ClaudeTimeoutException(
    super.message, {
    this.operation,
    this.timeout,
    super.cause,
    super.stackTrace,
  });

  @override
  bool get isRetryable => true;

  @override
  String toString() {
    final buffer = StringBuffer('ClaudeTimeoutException: $message');
    if (operation != null) {
      buffer.write('\nOperation: $operation');
    }
    if (timeout != null) {
      buffer.write('\nTimeout: ${timeout!.inMilliseconds}ms');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
