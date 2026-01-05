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
  });

  group('ProcessStartException', () {
    test('extends ClaudeApiException', () {
      final exception = ProcessStartException('Process failed');

      expect(exception, isA<ClaudeApiException>());
    });

    test('creates exception with all parameters', () {
      final cause = Exception('command not found');
      final trace = StackTrace.current;
      final exception = ProcessStartException(
        'Failed to start claude process',
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.message, 'Failed to start claude process');
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

  group('exception hierarchy', () {
    test('all exceptions can be caught as ClaudeApiException', () {
      final exceptions = [
        ClaudeApiException('base'),
        ProcessStartException('process'),
        ControlProtocolException('protocol'),
        ResponseParsingException('parsing'),
        ConversationLoadException('load'),
      ];

      for (final e in exceptions) {
        expect(e, isA<ClaudeApiException>());
        expect(e, isA<Exception>());
      }
    });

    test('specific exceptions can be caught individually', () {
      void throwProcessStart() => throw ProcessStartException('test');
      void throwControlProtocol() => throw ControlProtocolException('test');
      void throwParsing() => throw ResponseParsingException('test');
      void throwLoad() => throw ConversationLoadException('test');

      expect(throwProcessStart, throwsA(isA<ProcessStartException>()));
      expect(throwControlProtocol, throwsA(isA<ControlProtocolException>()));
      expect(throwParsing, throwsA(isA<ResponseParsingException>()));
      expect(throwLoad, throwsA(isA<ConversationLoadException>()));
    });
  });
}
