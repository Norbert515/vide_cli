import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:moondream_api/moondream_api.dart';

void main() {
  group('MoondreamClient', () {
    test('throws when API key is missing for cloud endpoint', () {
      expect(
        () => MoondreamClient(config: MoondreamConfig.defaults()),
        throwsArgumentError,
      );
    });

    test('allows missing API key for local endpoint', () {
      expect(
        () => MoondreamClient(
          config: MoondreamConfig(baseUrl: 'http://localhost:2020/v1'),
        ),
        returnsNormally,
      );
    });

    test('query makes correct request', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.toString(), endsWith('/query'));
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(request.headers['X-Moondream-Auth'], equals('test-key'));

        final body = jsonDecode(request.body);
        expect(body['image_url'], equals('data:image/jpeg;base64,ABC'));
        expect(body['question'], equals('What is this?'));

        return http.Response(jsonEncode({'answer': 'A test image'}), 200);
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      final response = await client.query(
        imageUrl: 'data:image/jpeg;base64,ABC',
        question: 'What is this?',
      );

      expect(response.answer, equals('A test image'));

      client.dispose();
    });

    test('caption makes correct request', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), endsWith('/caption'));

        final body = jsonDecode(request.body);
        expect(body['length'], equals('long'));

        return http.Response(
          jsonEncode({'caption': 'A detailed caption'}),
          200,
        );
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      final response = await client.caption(
        imageUrl: 'data:image/jpeg;base64,ABC',
        length: CaptionLength.long,
      );

      expect(response.caption, equals('A detailed caption'));

      client.dispose();
    });

    test('detect makes correct request', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), endsWith('/detect'));

        final body = jsonDecode(request.body);
        expect(body['object'], equals('car'));

        return http.Response(
          jsonEncode({
            'objects': [
              {'x_min': 10.0, 'y_min': 20.0, 'x_max': 100.0, 'y_max': 200.0},
            ],
          }),
          200,
        );
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      final response = await client.detect(
        imageUrl: 'data:image/jpeg;base64,ABC',
        object: 'car',
      );

      expect(response.objects, hasLength(1));
      expect(response.objects[0].xMin, equals(10.0));

      client.dispose();
    });

    test('point makes correct request', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), endsWith('/point'));

        final body = jsonDecode(request.body);
        expect(body['object'], equals('person'));

        return http.Response(jsonEncode({'x': 123.0, 'y': 456.0}), 200);
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      final response = await client.point(
        imageUrl: 'data:image/jpeg;base64,ABC',
        object: 'person',
      );

      expect(response.x, equals(123.0));
      expect(response.y, equals(456.0));

      client.dispose();
    });

    test('handles authentication error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Invalid API key',
              'type': 'authentication_error',
              'code': 'invalid_api_key',
            },
          }),
          401,
        );
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'invalid-key'),
        httpClient: mockClient,
      );

      expect(
        () => client.query(
          imageUrl: 'data:image/jpeg;base64,ABC',
          question: 'test',
        ),
        throwsA(isA<MoondreamAuthenticationException>()),
      );

      client.dispose();
    });

    test('handles rate limit error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Rate limit exceeded',
              'type': 'rate_limit_exceeded',
            },
          }),
          429,
        );
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      expect(
        () => client.query(
          imageUrl: 'data:image/jpeg;base64,ABC',
          question: 'test',
        ),
        throwsA(isA<MoondreamRateLimitException>()),
      );

      client.dispose();
    });

    test('handles invalid request error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Invalid image format',
              'type': 'invalid_request',
              'param': 'image_url',
            },
          }),
          400,
        );
      });

      final client = MoondreamClient(
        config: MoondreamConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      expect(
        () => client.query(imageUrl: 'invalid', question: 'test'),
        throwsA(isA<MoondreamInvalidRequestException>()),
      );

      client.dispose();
    });

    test('retries on network error', () async {
      var attemptCount = 0;

      final mockClient = MockClient((request) async {
        attemptCount++;
        if (attemptCount < 2) {
          throw Exception('Network error');
        }

        return http.Response(
          jsonEncode({'answer': 'Success after retry'}),
          200,
        );
      });

      final client = MoondreamClient(
        config: MoondreamConfig(
          apiKey: 'test-key',
          retryAttempts: 3,
          retryDelay: Duration.zero,
        ),
        httpClient: mockClient,
      );

      final response = await client.query(
        imageUrl: 'data:image/jpeg;base64,ABC',
        question: 'test',
      );

      expect(response.answer, equals('Success after retry'));
      expect(attemptCount, equals(2));

      client.dispose();
    });

    test('gives up after max retries', () async {
      var attemptCount = 0;

      final mockClient = MockClient((request) async {
        attemptCount++;
        throw Exception('Persistent network error');
      });

      final client = MoondreamClient(
        config: MoondreamConfig(
          apiKey: 'test-key',
          retryAttempts: 3,
          retryDelay: Duration.zero,
        ),
        httpClient: mockClient,
      );

      try {
        await client.query(
          imageUrl: 'data:image/jpeg;base64,ABC',
          question: 'test',
        );
        fail('Should have thrown MoondreamNetworkException');
      } on MoondreamNetworkException {
        // Expected
      }

      expect(attemptCount, equals(3));

      client.dispose();
    });
  });
}
