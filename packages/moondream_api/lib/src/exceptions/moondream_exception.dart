/// Base exception for Moondream API errors
class MoondreamException implements Exception {
  final String message;
  final String? type;
  final String? param;
  final String? code;
  final int? statusCode;
  final StackTrace? stackTrace;

  const MoondreamException({
    required this.message,
    this.type,
    this.param,
    this.code,
    this.statusCode,
    this.stackTrace,
  });

  factory MoondreamException.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
    StackTrace? stackTrace,
  }) {
    final message = json['message'] as String? ?? 'Unknown error';
    final type = json['type'] as String?;
    final param = json['param'] as String?;
    final code = json['code'] as String?;

    // Create specific exception types based on error type or status code
    if (statusCode == 401 || type == 'authentication_error') {
      return MoondreamAuthenticationException(
        message: message,
        type: type,
        param: param,
        code: code,
        statusCode: statusCode,
        stackTrace: stackTrace,
      );
    } else if (statusCode == 429 || type == 'rate_limit_exceeded') {
      return MoondreamRateLimitException(
        message: message,
        type: type,
        param: param,
        code: code,
        statusCode: statusCode,
        stackTrace: stackTrace,
      );
    } else if (statusCode == 400 || type == 'invalid_request') {
      return MoondreamInvalidRequestException(
        message: message,
        type: type,
        param: param,
        code: code,
        statusCode: statusCode,
        stackTrace: stackTrace,
      );
    }

    return MoondreamException(
      message: message,
      type: type,
      param: param,
      code: code,
      statusCode: statusCode,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('MoondreamException: $message');
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    if (code != null) buffer.write(' [code: $code]');
    if (type != null) buffer.write(' [type: $type]');
    if (param != null) buffer.write(' [param: $param]');
    return buffer.toString();
  }
}

/// Authentication error (401)
class MoondreamAuthenticationException extends MoondreamException {
  const MoondreamAuthenticationException({
    required super.message,
    super.type = 'authentication_error',
    super.param,
    super.code,
    super.statusCode = 401,
    super.stackTrace,
  });
}

/// Rate limit exceeded error (429)
class MoondreamRateLimitException extends MoondreamException {
  const MoondreamRateLimitException({
    required super.message,
    super.type = 'rate_limit_exceeded',
    super.param,
    super.code,
    super.statusCode = 429,
    super.stackTrace,
  });
}

/// Invalid request error (400)
class MoondreamInvalidRequestException extends MoondreamException {
  const MoondreamInvalidRequestException({
    required super.message,
    super.type = 'invalid_request',
    super.param,
    super.code,
    super.statusCode = 400,
    super.stackTrace,
  });
}

/// Network or connection error
class MoondreamNetworkException extends MoondreamException {
  const MoondreamNetworkException({
    required super.message,
    super.type = 'network_error',
    super.stackTrace,
  });
}

/// Timeout error
class MoondreamTimeoutException extends MoondreamException {
  const MoondreamTimeoutException({
    super.message = 'Request timed out',
    super.type = 'timeout_error',
    super.stackTrace,
  });
}
