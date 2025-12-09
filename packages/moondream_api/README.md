# Moondream API

Dart client for the [Moondream Vision Language Model](https://moondream.ai) API.

Moondream is a compact 2B parameter VLM designed for efficient image understanding tasks including visual question answering, image captioning, object detection, and coordinate pointing.

## Features

- ✅ Visual Question Answering
- ✅ Image Captioning
- ✅ Object Detection with Bounding Boxes
- ✅ Object Coordinate Pointing
- ✅ Type-safe API with sealed classes
- ✅ Automatic retry with exponential backoff
- ✅ Comprehensive error handling
- ✅ Image encoding utilities
- ✅ Support for local and cloud endpoints

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  moondream_api:
    path: ../moondream_api
```

Then run:

```bash
dart pub get
```

## Quick Start

### 1. Get API Key

Get your API key from [Moondream Console](https://console.moondream.ai/)

Set it as an environment variable:

```bash
export MOONDREAM_API_KEY=your_api_key_here
```

### 2. Basic Usage

```dart
import 'package:moondream_api/moondream_api.dart';

Future<void> main() async {
  // Create client from environment variable
  final client = MoondreamClient.fromEnvironment();

  try {
    // Encode image to base64
    final imageUrl = ImageEncoder.encodeFile('image.jpg');

    // Ask a question about the image
    final response = await client.query(
      imageUrl: imageUrl,
      question: 'What is in this image?',
    );

    print(response.answer);
  } finally {
    client.dispose();
  }
}
```

## API Reference

### Visual Question Answering

Ask natural language questions about images:

```dart
final response = await client.query(
  imageUrl: imageUrl,
  question: 'What color is the car?',
);
print(response.answer); // "The car is red"
```

### Image Captioning

Generate descriptions of images:

```dart
final response = await client.caption(
  imageUrl: imageUrl,
  length: CaptionLength.normal, // short, normal, or long
);
print(response.caption);
```

### Object Detection

Detect objects with bounding boxes:

```dart
final response = await client.detect(
  imageUrl: imageUrl,
  object: 'person',
);

for (final box in response.objects) {
  print('Found at: (${box.xMin}, ${box.yMin}) to (${box.xMax}, ${box.yMax})');
  print('Size: ${box.width}x${box.height}');
  print('Center: ${box.center}');
}
```

### Object Pointing

Get center coordinates of objects:

```dart
final response = await client.point(
  imageUrl: imageUrl,
  object: 'face',
);
print('Face center: (${response.x}, ${response.y})');
```

## Configuration

### Custom Configuration

```dart
final client = MoondreamClient(
  config: MoondreamConfig(
    apiKey: 'your-api-key',
    baseUrl: 'https://api.moondream.ai/v1',
    timeout: Duration(seconds: 30),
    retryAttempts: 3,
    retryDelay: Duration(seconds: 1),
    verbose: true, // Enable logging
  ),
);
```

### Local Endpoint

Use Moondream Station for local deployment:

```dart
final client = MoondreamClient(
  config: MoondreamConfig(
    baseUrl: 'http://localhost:2020/v1',
    // No API key needed for local
  ),
);
```

## Image Encoding

The API requires images as base64-encoded data URIs:

```dart
// From file path
final imageUrl = ImageEncoder.encodeFile('path/to/image.jpg');

// From bytes
final imageUrl = ImageEncoder.encodeBytes(
  bytes,
  mimeType: 'image/png',
);

// From base64 string
final imageUrl = ImageEncoder.encodeBase64String(
  base64String,
  mimeType: 'image/jpeg',
);
```

Supported formats: JPEG, PNG, GIF, WebP

## Error Handling

```dart
try {
  final response = await client.query(
    imageUrl: imageUrl,
    question: 'What is this?',
  );
} on MoondreamAuthenticationException catch (e) {
  print('Invalid API key: ${e.message}');
} on MoondreamRateLimitException catch (e) {
  print('Rate limit exceeded: ${e.message}');
} on MoondreamInvalidRequestException catch (e) {
  print('Invalid request: ${e.message}');
} on MoondreamTimeoutException catch (e) {
  print('Request timed out: ${e.message}');
} on MoondreamNetworkException catch (e) {
  print('Network error: ${e.message}');
} on MoondreamException catch (e) {
  print('API error: ${e.message}');
}
```

## Rate Limits

- Free tier: 5,000 requests/day
- Paid tiers: Contact Moondream for higher limits
- Local deployment: No limits

The client automatically retries failed requests with exponential backoff.

## Testing

Run tests:

```bash
dart test
```

## License

MIT

## Resources

- [Moondream Documentation](https://docs.moondream.ai/)
- [API Reference](https://moondream.ai/c/docs/advanced/api)
- [Moondream Console](https://console.moondream.ai/)
- [GitHub Repository](https://github.com/vikhyat/moondream)
