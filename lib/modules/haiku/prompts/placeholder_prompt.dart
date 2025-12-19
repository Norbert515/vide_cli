/// Prompt builder for dynamic input field placeholder text
class PlaceholderPrompt {
  static String build(DateTime now) {
    final randomSeed = now.millisecondsSinceEpoch % 100;

    return '''
Generate witty placeholder text for an AI coding assistant input field.

Seed: $randomSeed

RULES:
- 3-5 words only
- Playful, slightly cheeky tone
- Like a friend asking what you want to work on
- BANNED: "What's on your mind", "Describe your", "Enter your", "Type here"
- Be creative! Think: "What are we breaking today?", "Got bugs?", "Your wish, my code..."

CRITICAL: Output ONLY the placeholder text itself.
NO explanations, NO options, NO numbering, NO markdown.
Just the 3-5 word phrase, nothing else.
''';
  }
}
