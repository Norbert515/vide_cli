import 'dart:async';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import 'ask_user_question_types.dart';

/// Provider for the AskUserQuestion service (singleton)
final askUserQuestionServiceProvider = Provider<AskUserQuestionService>((ref) {
  final service = AskUserQuestionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Service for handling AskUserQuestion requests between MCP tool and UI
///
/// This service:
/// 1. Receives requests from the MCP tool
/// 2. Emits them to the UI via stream
/// 3. Waits for UI to respond
/// 4. Returns the response to the MCP tool
class AskUserQuestionService {
  final _requestController =
      StreamController<AskUserQuestionRequest>.broadcast();
  final Map<String, Completer<AskUserQuestionResponse>> _pendingRequests = {};

  /// Stream of requests for the UI to display
  Stream<AskUserQuestionRequest> get requests => _requestController.stream;

  /// Request user answers for a set of questions
  /// Returns a map of question -> answer
  Future<Map<String, String>> askQuestions(
    List<AskUserQuestion> questions,
  ) async {
    final requestId = const Uuid().v4();
    final completer = Completer<AskUserQuestionResponse>();
    _pendingRequests[requestId] = completer;

    // Create and emit request
    final request = AskUserQuestionRequest(
      requestId: requestId,
      questions: questions,
    );
    _requestController.add(request);

    // Wait for UI response
    final response = await completer.future;
    _pendingRequests.remove(requestId);

    return response.answers;
  }

  /// Called by UI to respond to a question request
  void respondToRequest(String requestId, AskUserQuestionResponse response) {
    final completer = _pendingRequests[requestId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await _requestController.close();
    // Complete any pending requests with empty answers
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(const AskUserQuestionResponse(answers: {}));
      }
    }
    _pendingRequests.clear();
  }
}
