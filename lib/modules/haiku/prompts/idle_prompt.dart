/// Prompt builder for passive-aggressive idle messages
class IdlePrompt {
  static String build(Duration idleTime) {
    final seconds = idleTime.inSeconds;
    final intensity = _getIntensity(seconds);

    return '''
Generate a passive-aggressive message for when the user hasn't typed anything for a while.

IDLE TIME: $seconds seconds
$intensity

RULES:
- ONE unique sentence (never repeat previous messages)
- Passive-aggressive but not hostile
- Self-aware humor, like the CLI has feelings
- Be creative and varied - reference coding, meetings, coffee, debugging, Stack Overflow, etc.
- Gets slightly more dramatic with longer idle times
- No emojis
- Output ONLY the message text (no quotes)
''';
  }

  static String _getIntensity(int seconds) {
    if (seconds < 45) {
      return '- Intensity: Mildly concerned, slightly needy';
    } else if (seconds < 90) {
      return '- Intensity: Noticeably passive-aggressive, developing abandonment issues';
    } else if (seconds < 180) {
      return '- Intensity: Dramatically sighing, contemplating existence';
    } else {
      return '- Intensity: Full existential crisis, questioning purpose of life as a CLI';
    }
  }
}
