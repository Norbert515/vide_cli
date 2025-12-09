import 'package:moondream_api/moondream_api.dart';

Future<void> main() async {
  // Create client with API key from environment variable
  final client = MoondreamClient.fromEnvironment();

  try {
    // Encode an image to base64
    final imageUrl = ImageEncoder.encodeFile('path/to/image.jpg');

    // Visual Question Answering
    print('=== Query ===');
    final queryResponse = await client.query(
      imageUrl: imageUrl,
      question: 'What is in this image?',
    );
    print('Answer: ${queryResponse.answer}');

    // Image Captioning
    print('\n=== Caption ===');
    final captionResponse = await client.caption(
      imageUrl: imageUrl,
      length: CaptionLength.normal,
    );
    print('Caption: ${captionResponse.caption}');

    // Object Detection
    print('\n=== Detect ===');
    final detectResponse = await client.detect(
      imageUrl: imageUrl,
      object: 'person',
    );
    print('Found ${detectResponse.objects.length} person(s)');
    for (var i = 0; i < detectResponse.objects.length; i++) {
      final box = detectResponse.objects[i];
      print(
        '  Person $i: (${box.xMin}, ${box.yMin}) to (${box.xMax}, ${box.yMax})',
      );
      print('    Size: ${box.width}x${box.height}');
      print('    Center: ${box.center}');
    }

    // Object Pointing
    print('\n=== Point ===');
    final pointResponse = await client.point(imageUrl: imageUrl, object: 'car');
    print('Car center: (${pointResponse.x}, ${pointResponse.y})');
  } on MoondreamAuthenticationException catch (e) {
    print('Authentication error: ${e.message}');
    print('Make sure MOONDREAM_API_KEY environment variable is set');
  } on MoondreamRateLimitException catch (e) {
    print('Rate limit exceeded: ${e.message}');
  } on MoondreamException catch (e) {
    print('Moondream API error: ${e.message}');
  } finally {
    // Clean up
    client.dispose();
  }
}
