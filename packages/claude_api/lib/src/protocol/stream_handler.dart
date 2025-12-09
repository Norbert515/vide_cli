import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/response.dart';
import 'json_decoder.dart';

class StreamHandler {
  final JsonDecoder _decoder = JsonDecoder();
  final StreamController<ClaudeResponse> _responseController =
      StreamController<ClaudeResponse>.broadcast();

  Stream<ClaudeResponse> get responses => _responseController.stream;

  StreamSubscription<String>? _subscription;

  void attachToProcess(Process process) {
    print('[StreamHandler] Attaching to process PID: ${process.pid}');

    // Handle stdout
    _subscription = process.stdout
        .transform(utf8.decoder)
        .listen(
          _handleLine,
          onError: _handleError,
          onDone: () {
            print('[StreamHandler] stdout stream done');
            _handleDone();
          },
        );

    // Handle stderr for errors
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleStderr,
          onDone: () => print('[StreamHandler] stderr stream done'),
        );
  }

  void attachToLoggedProcess(Process process) {
    // Handle stdout
    _subscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleError, onDone: _handleDone);

    // Handle stderr for errors
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStderr);
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }

    print(
      '[StreamHandler] Received line: ${line.substring(0, line.length > 100 ? 100 : line.length)}${line.length > 100 ? '...' : ''}',
    );

    try {
      final response = _decoder.decodeSingle(line);
      if (response != null) {
        print('[StreamHandler] Parsed response type: ${response.runtimeType}');
        _responseController.add(response);
      } else {
        print('[StreamHandler] Could not parse line as response');
      }
    } catch (e) {
      print('[StreamHandler] Parse error: $e');
    }
  }

  void _handleStderr(String line) {
    if (line.isNotEmpty) {
      print('[StreamHandler] STDERR: $line');
      _responseController.add(
        ErrorResponse(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          error: 'CLI Error',
          details: line,
        ),
      );
    }
  }

  void _handleError(Object error) {
    print('[StreamHandler] Stream error: $error');
    _responseController.add(
      ErrorResponse(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        error: 'Stream error',
        details: error.toString(),
      ),
    );
  }

  void _handleDone() {
    print('[StreamHandler] Stream completed, sending completion response');
    // Send completion when the process ends
    _responseController.add(
      CompletionResponse(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        stopReason: 'process_ended',
      ),
    );
  }

  Future<void> dispose() async {
    print('[StreamHandler] Disposing stream handler');
    await _subscription?.cancel();
    await _responseController.close();
  }
}
