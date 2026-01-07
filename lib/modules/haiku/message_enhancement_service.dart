import 'package:vide_cli/modules/haiku/haiku_service.dart';
import 'package:vide_cli/modules/haiku/prompts/loading_words_prompt.dart';
import 'package:vide_cli/modules/haiku/prompts/code_sommelier_prompt.dart';
import 'package:vide_cli/modules/haiku/prompts/placeholder_prompt.dart';
import 'package:vide_cli/utils/code_detector.dart';
import 'package:vide_cli/services/vide_settings.dart';

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
  /// [userMessage] The user's message that may contain code.
  /// [setCommentary] Callback to set the generated commentary in the provider.
  static Future<void> generateSommelierCommentary(
    String userMessage,
    void Function(String) setCommentary,
  ) async {
    // Check if sommelier is enabled in settings
    if (!VideSettingsManager.instance.settings.codeSommelierEnabled) return;

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

  /// Generate dynamic placeholder text for the input field.
  ///
  /// [now] Current time for seeding randomness.
  /// [setPlaceholder] Callback to set the generated placeholder in the provider.
  static Future<void> generatePlaceholderText(
    DateTime now,
    void Function(String) setPlaceholder,
  ) async {
    final systemPrompt = PlaceholderPrompt.build(now);

    final placeholder = await HaikuService.invoke(
      systemPrompt: systemPrompt,
      userMessage: 'Generate placeholder text',
      delay: Duration.zero,
    );

    if (placeholder != null) {
      String text = placeholder.trim();

      // Validate: handle verbose multi-line responses
      if (text.contains('\n') || text.length > 50) {
        final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        String? shortLine;
        for (final line in lines) {
          if (line.startsWith('Here') ||
              line.startsWith('Alright') ||
              line.contains(':') ||
              line.startsWith('Pick') ||
              line.startsWith('I')) continue;
          final cleaned = line.replaceAll(RegExp(r'^[\*\-\d\.\)]+\s*'), '').replaceAll('**', '').trim();
          if (cleaned.length >= 3 && cleaned.length <= 45) {
            shortLine = cleaned;
            break;
          }
        }
        text = shortLine ?? 'Describe your goal (you can attach images)';
      }

      if (text.length > 50) {
        text = 'Describe your goal (you can attach images)';
      }

      setPlaceholder(text);
    }
  }
}
