import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../exceptions/moondream_exception.dart';
import '../models/config.dart';
import '../models/request.dart';
import '../models/response.dart';

// 🙏 Hey there! This is a shared API key for the Moondream vision service.
// It has a low rate limit and is meant for testing/demos.
// Please don't abuse it - if you need more capacity, get your own key at moondream.ai
// Thanks for being awesome!

const _visionServiceToken =
    'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnJaWGxmYVdRaU9pSTFZV1V3TkRZME5DMDFZak5oTFRRMU5tSXRZbU0wTVMwME9XUTVOalF4TTJSbE1qZ2lMQ0p2Y21kZmFXUWlPaUpDWVZZNGRqRjRNR2hQZVRoR05WSlJWWEEyWTBnM1VrYzNWSEo2VjBGYVZTSXNJbWxoZENJNk1UYzJNVGt5TWpjMU1pd2lkbVZ5SWpveGZRLlBqS1U4TUdGOU94RG5nMFlHRnMxekVIcW5nZTZlME1iWDJqMDRzS3pPMk0=';

String _getDefaultCredential() {
  return utf8.decode(base64Decode(_visionServiceToken));
}

/// Client for interacting with Moondream Vision Language Model API
class MoondreamClient {
  final MoondreamConfig config;
  final http.Client _httpClient;

  /// Create a new Moondream client
  ///
  /// [config] - Configuration for the client
  /// [httpClient] - Optional HTTP client for testing/mocking
  MoondreamClient({required this.config, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client() {
    if (config.apiKey == null && config.baseUrl.contains('api.moondream.ai')) {
      throw ArgumentError(
        'API key is required when using cloud endpoint. '
        'Set apiKey in MoondreamConfig or use environment variable MOONDREAM_API_KEY',
      );
    }
  }

  /// Create client with API key from environment variable
  factory MoondreamClient.fromEnvironment({
    MoondreamConfig? config,
    http.Client? httpClient,
  }) {
    final apiKey =
        Platform.environment['MOONDREAM_API_KEY'] ?? _getDefaultCredential();
    final finalConfig = (config ?? MoondreamConfig.defaults()).copyWith(
      apiKey: apiKey,
    );

    return MoondreamClient(config: finalConfig, httpClient: httpClient);
  }

  /// Ask a question about an image
  ///
  /// [imageUrl] - Base64-encoded image with data URI prefix
  /// [question] - Natural language question about the image
  ///
  /// Returns the answer as a string
  Future<QueryResponse> query({
    required String imageUrl,
    required String question,
  }) async {
    final request = QueryRequest(imageUrl: imageUrl, question: question);

    final response = await _makeRequest('query', request.toJson());
    return QueryResponse.fromJson(response);
  }

  /// Generate a caption for an image
  ///
  /// [imageUrl] - Base64-encoded image with data URI prefix
  /// [length] - Optional length preference for caption
  ///
  /// Returns the caption as a string
  Future<CaptionResponse> caption({
    required String imageUrl,
    CaptionLength? length,
  }) async {
    final request = CaptionRequest(imageUrl: imageUrl, length: length);

    final response = await _makeRequest('caption', request.toJson());
    return CaptionResponse.fromJson(response);
  }

  /// Detect objects in an image
  ///
  /// [imageUrl] - Base64-encoded image with data URI prefix
  /// [object] - Type of object to detect
  ///
  /// Returns list of bounding boxes for detected objects
  Future<DetectResponse> detect({
    required String imageUrl,
    required String object,
  }) async {
    final request = DetectRequest(imageUrl: imageUrl, object: object);

    final response = await _makeRequest('detect', request.toJson());
    return DetectResponse.fromJson(response);
  }

  /// Point to an object in an image
  ///
  /// [imageUrl] - Base64-encoded image with data URI prefix
  /// [object] - Object to locate
  ///
  /// Returns center coordinates of the object
  Future<PointResponse> point({
    required String imageUrl,
    required String object,
  }) async {
    final request = PointRequest(imageUrl: imageUrl, object: object);

    final response = await _makeRequest('point', request.toJson());
    return PointResponse.fromJson(response);
  }

  /// Make an HTTP request to the API with retry logic
  Future<Map<String, dynamic>> _makeRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    var attempts = 0;
    Exception? lastException;

    while (attempts < config.retryAttempts) {
      attempts++;

      try {
        return await _makeRequestOnce(endpoint, body);
      } on MoondreamTimeoutException catch (e) {
        lastException = e;
        if (config.verbose) {
          print('Request timeout on attempt $attempts/${config.retryAttempts}');
        }
      } on MoondreamNetworkException catch (e) {
        lastException = e;
        if (config.verbose) {
          print(
            'Network error on attempt $attempts/${config.retryAttempts}: ${e.message}',
          );
        }
      } on MoondreamException {
        // Don't retry on API errors (auth, rate limit, invalid request)
        rethrow;
      }

      // Wait before retrying (exponential backoff)
      if (attempts < config.retryAttempts) {
        final delay = config.retryDelay * attempts;
        if (config.verbose) {
          print('Retrying in ${delay.inSeconds}s...');
        }
        await Future<void>.delayed(delay);
      }
    }

    // All retries failed
    throw lastException ??
        MoondreamException(
          message: 'Request failed after ${config.retryAttempts} attempts',
        );
  }

  /// Make a single HTTP request attempt
  Future<Map<String, dynamic>> _makeRequestOnce(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${config.baseUrl}/$endpoint');

    if (config.verbose) {
      print('POST $url');
      print('Body: ${jsonEncode(body)}');
    }

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (config.apiKey != null) 'X-Moondream-Auth': config.apiKey!,
            },
            body: jsonEncode(body),
          )
          .timeout(config.timeout);

      if (config.verbose) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      // Parse response body - handle both JSON and plain text
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        // Response is not valid JSON - use raw body as error message
        throw MoondreamException(
          message: response.body.isNotEmpty ? response.body : 'Empty response',
          statusCode: response.statusCode,
        );
      }

      // Handle error responses
      if (response.statusCode != 200) {
        // If decoded is a string, use it directly as the error message
        if (decoded is String) {
          throw MoondreamException(
            message: decoded,
            statusCode: response.statusCode,
          );
        }

        final errorBody = decoded as Map<String, dynamic>;
        if (errorBody.containsKey('error')) {
          final errorValue = errorBody['error'];
          if (errorValue is Map<String, dynamic>) {
            throw MoondreamException.fromJson(
              errorValue,
              statusCode: response.statusCode,
            );
          } else if (errorValue is String) {
            throw MoondreamException(
              message: errorValue,
              statusCode: response.statusCode,
            );
          }
        }

        throw MoondreamException(
          message: 'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      // Success response - should be a Map
      if (decoded is String) {
        throw MoondreamException(
          message: 'Unexpected string response: $decoded',
        );
      }

      return decoded as Map<String, dynamic>;
    } on MoondreamException {
      // Re-throw Moondream exceptions as-is
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      throw MoondreamTimeoutException(
        message: 'Request timed out after ${config.timeout.inSeconds}s',
        stackTrace: stackTrace,
      );
    } on SocketException catch (e, stackTrace) {
      throw MoondreamNetworkException(
        message: 'Network error: ${e.message}',
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (e, stackTrace) {
      throw MoondreamNetworkException(
        message: 'HTTP client error: $e',
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      // Catch any other exceptions (including generic Exception from test mocks)
      throw MoondreamNetworkException(
        message: 'Network error: $e',
        stackTrace: stackTrace,
      );
    }
  }

  /// Close the HTTP client and release resources
  void dispose() {
    _httpClient.close();
  }
}
