import 'package:nocterm_riverpod/nocterm_riverpod.dart';

/// Dynamic loading words - shown during agent processing
final loadingWordsProvider = StateProvider<List<String>?>((ref) => null);

/// Dynamic placeholder text for input field
final placeholderTextProvider = StateProvider<String?>((ref) => null);

/// Idle detector message - shown after inactivity
final idleMessageProvider = StateProvider<String?>((ref) => null);

/// Activity tip - shown during long operations
final activityTipProvider = StateProvider<String?>((ref) => null);

/// Code sommelier commentary
final codeSommelierProvider = StateProvider<String?>((ref) => null);

/// Sub-agent progress summary
final agentProgressSummaryProvider = StateProvider<String?>((ref) => null);

/// Code change summary
final changeSummaryProvider = StateProvider<String?>((ref) => null);

/// Error triage result
final errorTriageProvider = StateProvider<String?>((ref) => null);

/// Task complexity estimate
final complexityEstimateProvider = StateProvider<String?>((ref) => null);

/// Long response TL;DR
final tldrProvider = StateProvider<String?>((ref) => null);

/// Session token usage tracking
class SessionTokenUsage {
  final int inputTokens;
  final int outputTokens;

  const SessionTokenUsage({this.inputTokens = 0, this.outputTokens = 0});

  int get totalTokens => inputTokens + outputTokens;

  SessionTokenUsage add({int input = 0, int output = 0}) {
    return SessionTokenUsage(
      inputTokens: inputTokens + input,
      outputTokens: outputTokens + output,
    );
  }
}

final sessionTokenUsageProvider = StateProvider<SessionTokenUsage>((ref) => const SessionTokenUsage());
