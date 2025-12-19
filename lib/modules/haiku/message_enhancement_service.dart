import 'package:vide_cli/modules/haiku/haiku_service.dart';
import 'package:vide_cli/modules/haiku/prompts/loading_words_prompt.dart';
import 'package:vide_cli/modules/haiku/prompts/code_sommelier_prompt.dart';
import 'package:vide_cli/utils/code_detector.dart';

/// Centralized service for message enhancement features.
/// Handles loading words generation and code sommelier commentary.
///
/// Uses a callback-based API so callers can provide their own way to
/// set the provider state (supporting both Ref and BuildContext usage).
class MessageEnhancementService {
  /// Generate creative loading words for a user message.
  ///
  /// [userMessage] The user's message to generate loading words for.
  /// [setLoadingWords] Callback to set the generated words in the provider.
  static Future<void> generateLoadingWords(
    String userMessage,
    void Function(List<String>) setLoadingWords,
  ) async {
    final systemPrompt = LoadingWordsPrompt.build(DateTime.now());
    final wrappedMessage = 'Generate loading words for this task: "$userMessage"';

    final words = await HaikuService.invokeForList(
      systemPrompt: systemPrompt,
      userMessage: wrappedMessage,
      lineEnding: '...',
      maxItems: 5,
    );
    if (words != null) {
      setLoadingWords(words);
    }
  }

  /// Generate wine-tasting style commentary for code in a message.
  ///
  /// NOTE: This feature requires VideSettingsManager which is not available in this branch.
  /// The method is kept for API compatibility but currently does nothing.
  /// Enable by adding vide_settings.dart and calling this method from integration points.
  ///
  /// [userMessage] The user's message that may contain code.
  /// [setCommentary] Callback to set the generated commentary in the provider.
  static Future<void> generateSommelierCommentary(
    String userMessage,
    void Function(String) setCommentary,
  ) async {
    // Sommelier feature disabled in this branch - settings service not available
    // To enable: add vide_settings.dart and uncomment the implementation below
    return;

    // ignore: dead_code
    if (!CodeDetector.containsCode(userMessage)) return;

    final extractedCode = CodeDetector.extractCode(userMessage);
    final truncatedCode = extractedCode.length > 2000
        ? '${extractedCode.substring(0, 2000)}...'
        : extractedCode;
    final systemPrompt = CodeSommelierPrompt.build(truncatedCode);

    final commentary = await HaikuService.invoke(
      systemPrompt: systemPrompt,
      userMessage: 'Analyze this code.',
    );

    if (commentary != null) {
      setCommentary(commentary);
    }
  }
}
