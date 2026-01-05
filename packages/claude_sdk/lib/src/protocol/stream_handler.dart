import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/response.dart';
import 'json_decoder.dart';

/// Handles streaming responses from a Claude CLI process.
///
/// This class parses JSON responses from the process stdout and
/// converts them into typed [ClaudeResponse] objects.
class StreamHandler {
  final JsonDecoder _decoder = JsonDecoder();
  final StreamController<ClaudeResponse> _responseController =
      StreamController<ClaudeResponse>.broadcast();

  /// Stream of parsed responses from the process.
  Stream<ClaudeResponse> get responses => _responseController.stream;

  StreamSubscription<String>? _subscription;

  /// Attach to a process and start parsing its output.
  void attachToProcess(Process process) {
    // Handle stdout
    _subscription = process.stdout
        .transform(utf8.decoder)
        .listen(_handleLine, onError: _handleError, onDone: _handleDone);

    // Handle stderr for errors
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStderr);
  }

  /// Attach to a logged process (line-by-line output).
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

    final response = _decoder.decodeSingle(line);
    if (response != null) {
      _responseController.add(response);
    }
  }

  void _handleStderr(String line) {
    if (line.isNotEmpty) {
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
    // Send completion when the process ends
    _responseController.add(
      CompletionResponse(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        stopReason: 'process_ended',
      ),
    );
  }

  /// Dispose of resources and close the response stream.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _responseController.close();
  }
}
