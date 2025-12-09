import 'package:test/test.dart';
import 'package:moondream_api/moondream_api.dart';

void main() {
  group('MoondreamConfig', () {
    test('creates default config', () {
      final config = MoondreamConfig.defaults();

      expect(config.baseUrl, equals('https://api.moondream.ai/v1'));
      expect(config.timeout, equals(const Duration(seconds: 30)));
      expect(config.retryAttempts, equals(3));
      expect(config.verbose, isFalse);
      expect(config.apiKey, isNull);
    });

    test('creates config with custom values', () {
      final config = MoondreamConfig(
        apiKey: 'test-key',
        baseUrl: 'http://localhost:2020/v1',
        timeout: const Duration(seconds: 60),
        retryAttempts: 5,
        verbose: true,
      );

      expect(config.apiKey, equals('test-key'));
      expect(config.baseUrl, equals('http://localhost:2020/v1'));
      expect(config.timeout, equals(const Duration(seconds: 60)));
      expect(config.retryAttempts, equals(5));
      expect(config.verbose, isTrue);
    });

    test('copyWith creates modified config', () {
      final original = MoondreamConfig.defaults();
      final modified = original.copyWith(apiKey: 'new-key', verbose: true);

      expect(modified.apiKey, equals('new-key'));
      expect(modified.verbose, isTrue);
      expect(modified.baseUrl, equals(original.baseUrl));
      expect(modified.timeout, equals(original.timeout));
    });
  });

  group('Request Models', () {
    test('QueryRequest serializes correctly', () {
      final request = QueryRequest(
        imageUrl: 'data:image/jpeg;base64,ABC',
        question: 'What is this?',
      );

      final json = request.toJson();

      expect(json['image_url'], equals('data:image/jpeg;base64,ABC'));
      expect(json['question'], equals('What is this?'));
    });

    test('CaptionRequest serializes correctly', () {
      final request = CaptionRequest(
        imageUrl: 'data:image/jpeg;base64,ABC',
        length: CaptionLength.long,
      );

      final json = request.toJson();

      expect(json['image_url'], equals('data:image/jpeg;base64,ABC'));
      expect(json['length'], equals('long'));
    });

    test('DetectRequest serializes correctly', () {
      final request = DetectRequest(
        imageUrl: 'data:image/jpeg;base64,ABC',
        object: 'car',
      );

      final json = request.toJson();

      expect(json['image_url'], equals('data:image/jpeg;base64,ABC'));
      expect(json['object'], equals('car'));
    });

    test('PointRequest serializes correctly', () {
      final request = PointRequest(
        imageUrl: 'data:image/jpeg;base64,ABC',
        object: 'person',
      );

      final json = request.toJson();

      expect(json['image_url'], equals('data:image/jpeg;base64,ABC'));
      expect(json['object'], equals('person'));
    });
  });

  group('Response Models', () {
    test('QueryResponse parses correctly', () {
      final json = {'answer': 'A beautiful sunset'};
      final response = QueryResponse.fromJson(json);

      expect(response.answer, equals('A beautiful sunset'));
    });

    test('CaptionResponse parses correctly', () {
      final json = {'caption': 'A cat sitting on a couch'};
      final response = CaptionResponse.fromJson(json);

      expect(response.caption, equals('A cat sitting on a couch'));
    });

    test('DetectResponse parses correctly', () {
      final json = {
        'objects': <Map<String, dynamic>>[
          {'x_min': 10.0, 'y_min': 20.0, 'x_max': 100.0, 'y_max': 200.0},
          {'x_min': 50.0, 'y_min': 60.0, 'x_max': 150.0, 'y_max': 160.0},
        ],
      };
      final response = DetectResponse.fromJson(json);

      expect(response.objects, hasLength(2));
      expect(response.objects[0].xMin, equals(10.0));
      expect(response.objects[0].yMax, equals(200.0));
    });

    test('PointResponse parses correctly', () {
      final json = {'x': 123.0, 'y': 456.0};
      final response = PointResponse.fromJson(json);

      expect(response.x, equals(123.0));
      expect(response.y, equals(456.0));
    });

    test('BoundingBox calculates dimensions correctly', () {
      final box = BoundingBox(xMin: 10.0, yMin: 20.0, xMax: 110.0, yMax: 120.0);

      expect(box.width, equals(100.0));
      expect(box.height, equals(100.0));
      expect(box.area, equals(10000.0));
      expect(box.center.x, equals(60.0));
      expect(box.center.y, equals(70.0));
    });
  });

  group('MoondreamResponse factory', () {
    test('creates QueryResponse from JSON', () {
      final json = {'answer': 'test'};
      final response = MoondreamResponse.fromJson(json);

      expect(response, isA<QueryResponse>());
      expect((response as QueryResponse).answer, equals('test'));
    });

    test('creates CaptionResponse from JSON', () {
      final json = {'caption': 'test'};
      final response = MoondreamResponse.fromJson(json);

      expect(response, isA<CaptionResponse>());
      expect((response as CaptionResponse).caption, equals('test'));
    });

    test('creates DetectResponse from JSON', () {
      final json = {'objects': <Map<String, dynamic>>[]};
      final response = MoondreamResponse.fromJson(json);

      expect(response, isA<DetectResponse>());
    });

    test('creates PointResponse from JSON', () {
      final json = {'x': 1.0, 'y': 2.0};
      final response = MoondreamResponse.fromJson(json);

      expect(response, isA<PointResponse>());
    });

    test('throws on unknown response format', () {
      final json = {'unknown': 'field'};

      expect(() => MoondreamResponse.fromJson(json), throwsFormatException);
    });
  });
}
