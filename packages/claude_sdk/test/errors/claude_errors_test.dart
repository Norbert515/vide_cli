import 'package:claude_sdk/src/errors/claude_errors.dart';
import 'package:test/test.dart';

void main() {
  group('ClaudeApiException', () {
    test('creates exception with message only', () {
      final exception = ClaudeApiException('Something went wrong');

      expect(exception.message, 'Something went wrong');
      expect(exception.cause, isNull);
      expect(exception.stackTrace, isNull);
    });

    test('creates exception with cause', () {
      final cause = Exception('Root cause');
      final exception = ClaudeApiException(
        'Something went wrong',
        cause: cause,
      );

      expect(exception.message, 'Something went wrong');
      expect(exception.cause, cause);
    });

    test('creates exception with stack trace', () {
      final trace = StackTrace.current;
      final exception = ClaudeApiException(
        'Something went wrong',
        stackTrace: trace,
      );

      expect(exception.stackTrace, trace);
    });

    test('toString includes message', () {
      final exception = ClaudeApiException('Test error');

      expect(exception.toString(), contains('ClaudeApiException'));
      expect(exception.toString(), contains('Test error'));
    });

    test('toString includes cause when present', () {
      final exception = ClaudeApiException('Test error', cause: 'Root cause');

      expect(exception.toString(), contains('Caused by: Root cause'));
    });

    test('is catchable as Exception', () {
      expect(() => throw ClaudeApiException('test'), throwsA(isA<Exception>()));
    });

    test('isRetryable defaults to false', () {
      final exception = ClaudeApiException('test');
      expect(exception.isRetryable, isFalse);
    });
  });

  group('CliNotFoundException', () {
    test('creates exception with default message', () {
      final exception = CliNotFoundException();

      expect(exception.message, 'Claude Code CLI not found');
      expect(exception.cliPath, isNull);
    });

    test('creates exception with custom message and path', () {
      final exception = CliNotFoundException(
        message: 'CLI not in PATH',
        cliPath: '/usr/local/bin/claude',
      );

      expect(exception.message, 'CLI not in PATH');
      expect(exception.cliPath, '/usr/local/bin/claude');
    });

    test('toString includes install instructions', () {
      final exception = CliNotFoundException();

      expect(exception.toString(), contains('CliNotFoundException'));
      expect(exception.toString(), contains('npm install'));
    });

    test('toString includes searched path when present', () {
      final exception = CliNotFoundException(cliPath: '/custom/path');

      expect(exception.toString(), contains('Searched path: /custom/path'));
    });

    test('extends ClaudeApiException', () {
      expect(CliNotFoundException(), isA<ClaudeApiException>());
    });
  });

  group('ProcessException', () {
    test('creates exception with exit code and stderr', () {
      final exception = ProcessException(
        'Process failed',
        exitCode: 1,
        stderr: 'Error output',
      );

      expect(exception.message, 'Process failed');
      expect(exception.exitCode, 1);
      expect(exception.stderr, 'Error output');
    });

    test('toString includes exit code', () {
      final exception = ProcessException('Failed', exitCode: 127);

      expect(exception.toString(), contains('Exit code: 127'));
    });

    test('toString includes stderr when present', () {
      final exception = ProcessException('Failed', stderr: 'command not found');

      expect(exception.toString(), contains('Stderr: command not found'));
    });

    test('toString omits empty stderr', () {
      final exception = ProcessException('Failed', stderr: '');

      expect(exception.toString(), isNot(contains('Stderr:')));
    });

    test('extends ClaudeApiException', () {
      expect(ProcessException('test'), isA<ClaudeApiException>());
    });
  });

  group('ProcessStartException', () {
    test('extends ProcessException', () {
      final exception = ProcessStartException('Process failed');

      expect(exception, isA<ProcessException>());
      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with all parameters', () {
      final cause = Exception('command not found');
      final trace = StackTrace.current;
      final exception = ProcessStartException(
        'Failed to start claude process',
        exitCode: 127,
        stderr: 'claude: command not found',
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.message, 'Failed to start claude process');
      expect(exception.exitCode, 127);
      expect(exception.stderr, 'claude: command not found');
      expect(exception.cause, cause);
      expect(exception.stackTrace, trace);
    });

    test('toString includes ProcessStartException prefix', () {
      final exception = ProcessStartException('Process failed');

      expect(exception.toString(), contains('ProcessStartException'));
      expect(exception.toString(), contains('Process failed'));
    });

    test('is catchable as ClaudeApiException', () {
      expect(
        () => throw ProcessStartException('test'),
        throwsA(isA<ClaudeApiException>()),
      );
    });
  });

  group('ControlProtocolException', () {
    test('extends ClaudeApiException', () {
      final exception = ControlProtocolException('Protocol error');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with all parameters', () {
      final cause = FormatException('Invalid JSON');
      final trace = StackTrace.current;
      final exception = ControlProtocolException(
        'Control protocol connection failed',
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.message, 'Control protocol connection failed');
      expect(exception.cause, cause);
      expect(exception.stackTrace, trace);
    });

    test('toString includes ControlProtocolException prefix', () {
      final exception = ControlProtocolException('Protocol error');

      expect(exception.toString(), contains('ControlProtocolException'));
      expect(exception.toString(), contains('Protocol error'));
    });
  });

  group('ResponseParsingException', () {
    test('extends ClaudeApiException', () {
      final exception = ResponseParsingException('Parse failed');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with raw response', () {
      final exception = ResponseParsingException(
        'Invalid JSON',
        rawResponse: '{"invalid: json}',
      );

      expect(exception.message, 'Invalid JSON');
      expect(exception.rawResponse, '{"invalid: json}');
    });

    test('toString includes raw response when present', () {
      final exception = ResponseParsingException(
        'Parse failed',
        rawResponse: 'bad data',
      );

      expect(exception.toString(), contains('Raw response: bad data'));
    });

    test('toString does not include raw response when null', () {
      final exception = ResponseParsingException('Parse failed');

      expect(exception.toString(), isNot(contains('Raw response:')));
    });
  });

  group('ConversationLoadException', () {
    test('extends ClaudeApiException', () {
      final exception = ConversationLoadException('Load failed');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with session ID', () {
      final exception = ConversationLoadException(
        'Failed to load conversation',
        sessionId: 'session-123',
      );

      expect(exception.message, 'Failed to load conversation');
      expect(exception.sessionId, 'session-123');
    });

    test('toString includes session ID when present', () {
      final exception = ConversationLoadException(
        'Load failed',
        sessionId: 'session-456',
      );

      expect(exception.toString(), contains('Session ID: session-456'));
    });

    test('toString does not include session ID when null', () {
      final exception = ConversationLoadException('Load failed');

      expect(exception.toString(), isNot(contains('Session ID:')));
    });
  });

  group('MessageParseException', () {
    test('extends ClaudeApiException', () {
      final exception = MessageParseException('Parse failed');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with data', () {
      final data = {'type': 'unknown', 'content': 'test'};
      final exception = MessageParseException(
        'Unknown message type',
        data: data,
      );

      expect(exception.message, 'Unknown message type');
      expect(exception.data, data);
    });

    test('toString includes data when present', () {
      final exception = MessageParseException(
        'Parse failed',
        data: {'key': 'value'},
      );

      expect(exception.toString(), contains('Data:'));
      expect(exception.toString(), contains('key'));
    });
  });

  group('ApiErrorType', () {
    test('fromString parses known error types', () {
      expect(
        ApiErrorType.fromString('invalid_request_error'),
        ApiErrorType.invalidRequest,
      );
      expect(
        ApiErrorType.fromString('authentication_error'),
        ApiErrorType.authentication,
      );
      expect(
        ApiErrorType.fromString('rate_limit_error'),
        ApiErrorType.rateLimit,
      );
      expect(ApiErrorType.fromString('api_error'), ApiErrorType.api);
      expect(
        ApiErrorType.fromString('overloaded_error'),
        ApiErrorType.overloaded,
      );
    });

    test('fromString returns unknown for null', () {
      expect(ApiErrorType.fromString(null), ApiErrorType.unknown);
    });

    test('fromString returns unknown for unrecognized values', () {
      expect(
        ApiErrorType.fromString('some_random_error'),
        ApiErrorType.unknown,
      );
    });
  });

  group('ApiException', () {
    test('extends ClaudeApiException', () {
      final exception = ApiException('API error');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with all parameters', () {
      final exception = ApiException(
        'Invalid request',
        errorType: ApiErrorType.invalidRequest,
        statusCode: 400,
        requestId: 'req_123',
      );

      expect(exception.message, 'Invalid request');
      expect(exception.errorType, ApiErrorType.invalidRequest);
      expect(exception.statusCode, 400);
      expect(exception.requestId, 'req_123');
    });

    test('toString includes error type and status code', () {
      final exception = ApiException(
        'Bad request',
        errorType: ApiErrorType.invalidRequest,
        statusCode: 400,
      );

      expect(exception.toString(), contains('ApiException'));
      expect(exception.toString(), contains('invalid_request_error'));
      expect(exception.toString(), contains('Status code: 400'));
    });

    test('toString includes request ID when present', () {
      final exception = ApiException('Error', requestId: 'req_abc123');

      expect(exception.toString(), contains('Request ID: req_abc123'));
    });

    test('isRetryable returns true for server errors', () {
      expect(
        ApiException('Error', errorType: ApiErrorType.api).isRetryable,
        isTrue,
      );
      expect(
        ApiException('Error', errorType: ApiErrorType.overloaded).isRetryable,
        isTrue,
      );
      expect(
        ApiException('Error', errorType: ApiErrorType.rateLimit).isRetryable,
        isTrue,
      );
    });

    test('isRetryable returns false for client errors', () {
      expect(
        ApiException(
          'Error',
          errorType: ApiErrorType.invalidRequest,
        ).isRetryable,
        isFalse,
      );
      expect(
        ApiException(
          'Error',
          errorType: ApiErrorType.authentication,
        ).isRetryable,
        isFalse,
      );
      expect(
        ApiException('Error', errorType: ApiErrorType.permission).isRetryable,
        isFalse,
      );
      expect(
        ApiException(
          'Error',
          errorType: ApiErrorType.requestTooLarge,
        ).isRetryable,
        isFalse,
      );
    });

    test('fromResponse creates correct exception type', () {
      final exception = ApiException.fromResponse(
        message: 'Too many requests',
        errorType: 'rate_limit_error',
        statusCode: 429,
      );

      expect(exception, isA<RateLimitException>());
      expect(exception.statusCode, 429);
    });

    test('fromResponse creates ApiException for non-rate-limit errors', () {
      final exception = ApiException.fromResponse(
        message: 'Invalid input',
        errorType: 'invalid_request_error',
        statusCode: 400,
      );

      expect(exception, isA<ApiException>());
      expect(exception, isNot(isA<RateLimitException>()));
      expect(exception.errorType, ApiErrorType.invalidRequest);
    });
  });

  group('RateLimitException', () {
    test('extends ApiException', () {
      final exception = RateLimitException('Rate limited');

      expect(exception, isA<ApiException>());
      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with retry-after duration', () {
      final exception = RateLimitException(
        'Too many requests',
        retryAfter: Duration(seconds: 30),
        statusCode: 429,
      );

      expect(exception.message, 'Too many requests');
      expect(exception.retryAfter, Duration(seconds: 30));
      expect(exception.statusCode, 429);
      expect(exception.errorType, ApiErrorType.rateLimit);
    });

    test('isRetryable is always true', () {
      final exception = RateLimitException('Rate limited');

      expect(exception.isRetryable, isTrue);
    });

    test('toString includes retry-after duration', () {
      final exception = RateLimitException(
        'Rate limited',
        retryAfter: Duration(seconds: 60),
      );

      expect(exception.toString(), contains('RateLimitException'));
      expect(exception.toString(), contains('Retry after: 60s'));
    });
  });

  group('ClaudeTimeoutException', () {
    test('extends ClaudeApiException', () {
      final exception = ClaudeTimeoutException('Timed out');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with operation and timeout', () {
      final exception = ClaudeTimeoutException(
        'Operation timed out',
        operation: 'getMcpStatus',
        timeout: Duration(seconds: 30),
      );

      expect(exception.message, 'Operation timed out');
      expect(exception.operation, 'getMcpStatus');
      expect(exception.timeout, Duration(seconds: 30));
    });

    test('isRetryable is true', () {
      final exception = ClaudeTimeoutException('Timed out');

      expect(exception.isRetryable, isTrue);
    });

    test('toString includes operation and timeout', () {
      final exception = ClaudeTimeoutException(
        'Timed out',
        operation: 'sendMessage',
        timeout: Duration(milliseconds: 5000),
      );

      expect(exception.toString(), contains('ClaudeTimeoutException'));
      expect(exception.toString(), contains('Operation: sendMessage'));
      expect(exception.toString(), contains('Timeout: 5000ms'));
    });
  });

  group('exception hierarchy', () {
    test('all exceptions can be caught as ClaudeApiException', () {
      final exceptions = [
        ClaudeApiException('base'),
        CliNotFoundException(),
        ProcessException('process'),
        ProcessStartException('process start'),
        ControlProtocolException('protocol'),
        ResponseParsingException('parsing'),
        MessageParseException('message parse'),
        ConversationLoadException('load'),
        ApiException('api'),
        RateLimitException('rate limit'),
        ClaudeTimeoutException('timeout'),
      ];

      for (final e in exceptions) {
        expect(e, isA<ClaudeApiException>());
        expect(e, isA<Exception>());
      }
    });

    test('specific exceptions can be caught individually', () {
      void throwCliNotFound() => throw CliNotFoundException();
      void throwProcess() => throw ProcessException('test');
      void throwProcessStart() => throw ProcessStartException('test');
      void throwControlProtocol() => throw ControlProtocolException('test');
      void throwParsing() => throw ResponseParsingException('test');
      void throwMessageParse() => throw MessageParseException('test');
      void throwLoad() => throw ConversationLoadException('test');
      void throwApi() => throw ApiException('test');
      void throwRateLimit() => throw RateLimitException('test');
      void throwTimeout() => throw ClaudeTimeoutException('test');

      expect(throwCliNotFound, throwsA(isA<CliNotFoundException>()));
      expect(throwProcess, throwsA(isA<ProcessException>()));
      expect(throwProcessStart, throwsA(isA<ProcessStartException>()));
      expect(throwControlProtocol, throwsA(isA<ControlProtocolException>()));
      expect(throwParsing, throwsA(isA<ResponseParsingException>()));
      expect(throwMessageParse, throwsA(isA<MessageParseException>()));
      expect(throwLoad, throwsA(isA<ConversationLoadException>()));
      expect(throwApi, throwsA(isA<ApiException>()));
      expect(throwRateLimit, throwsA(isA<RateLimitException>()));
      expect(throwTimeout, throwsA(isA<ClaudeTimeoutException>()));
    });

    test('ProcessStartException can be caught as ProcessException', () {
      void throwProcessStart() => throw ProcessStartException('test');

      expect(throwProcessStart, throwsA(isA<ProcessException>()));
    });

    test('RateLimitException can be caught as ApiException', () {
      void throwRateLimit() => throw RateLimitException('test');

      expect(throwRateLimit, throwsA(isA<ApiException>()));
    });
  });

  group('isRetryable behavior', () {
    test('retryable exceptions return true', () {
      final retryableExceptions = [
        RateLimitException('rate limit'),
        ApiException('server error', errorType: ApiErrorType.api),
        ApiException('overloaded', errorType: ApiErrorType.overloaded),
        ClaudeTimeoutException('timeout'),
      ];

      for (final e in retryableExceptions) {
        expect(
          e.isRetryable,
          isTrue,
          reason: '${e.runtimeType} should be retryable',
        );
      }
    });

    test('non-retryable exceptions return false', () {
      final nonRetryableExceptions = [
        ClaudeApiException('base'),
        CliNotFoundException(),
        ProcessException('process'),
        ProcessStartException('start'),
        ControlProtocolException('protocol'),
        ResponseParsingException('parse'),
        MessageParseException('message'),
        ConversationLoadException('load'),
        ApiException('invalid', errorType: ApiErrorType.invalidRequest),
        ApiException('auth', errorType: ApiErrorType.authentication),
        ApiException('permission', errorType: ApiErrorType.permission),
        ApiException('not found', errorType: ApiErrorType.notFound),
        ApiException('too large', errorType: ApiErrorType.requestTooLarge),
      ];

      for (final e in nonRetryableExceptions) {
        expect(
          e.isRetryable,
          isFalse,
          reason: '${e.runtimeType} should not be retryable',
        );
      }
    });
  });
}
