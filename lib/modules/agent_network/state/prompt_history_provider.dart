import 'package:nocterm_riverpod/nocterm_riverpod.dart';

/// Maximum number of prompts to keep in history.
const int _maxHistoryLength = 100;

/// Provider for prompt history. Newest prompts are at the front of the list.
final promptHistoryProvider =
    StateNotifierProvider<PromptHistoryNotifier, List<String>>((ref) {
      return PromptHistoryNotifier();
    });

class PromptHistoryNotifier extends StateNotifier<List<String>> {
  PromptHistoryNotifier() : super([]);

  /// Add a prompt to the history. Duplicates of the most recent entry are skipped.
  void addPrompt(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    // Skip if it's the same as the most recent prompt
    if (state.isNotEmpty && state.first == trimmed) return;

    // Add to front (newest first) and limit size
    state = [trimmed, ...state.take(_maxHistoryLength - 1)];
  }

  /// Clear all history.
  void clear() {
    state = [];
  }
}

/// Provider for preserving pending input text when dialogs interrupt typing.
/// This allows the text field to restore its content after being remounted.
final pendingInputTextProvider = StateProvider<String>((ref) => '');
