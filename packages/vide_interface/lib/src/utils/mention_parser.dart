/// Parses @mention prefixes from message text.
library;

/// Parsed @mention target.
sealed class MentionTarget {
  const MentionTarget();
}

final class UserMention extends MentionTarget {
  const UserMention();
}

final class EveryoneMention extends MentionTarget {
  const EveryoneMention();
}

final class AgentMention extends MentionTarget {
  final String agentId;
  const AgentMention(this.agentId);
}

final class NoMention extends MentionTarget {
  const NoMention();
}

/// Parse result with target + remaining body text.
typedef MentionParseResult = ({MentionTarget target, String body});

/// UUID pattern: 8-4-4-4-12 hex characters.
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Full prefix regex: optional leading whitespace, @, then keyword or UUID,
/// followed by whitespace boundary or end-of-string.
final _mentionPrefix = RegExp(
  r'^\s*@([a-zA-Z0-9-]+)(?:\s+|$)',
);

abstract final class MentionParser {
  /// Parse @mention from the START of message text.
  ///
  /// - `@user` -> UserMention
  /// - `@everyone` -> EveryoneMention
  /// - `@{uuid}` -> AgentMention
  /// - anything else -> NoMention
  static MentionParseResult parse(String text) {
    final match = _mentionPrefix.firstMatch(text);
    if (match == null) {
      return (target: const NoMention(), body: text);
    }

    final keyword = match.group(1)!;

    if (keyword == 'user') {
      return (
        target: const UserMention(),
        body: text.substring(match.end),
      );
    }

    if (keyword == 'everyone') {
      return (
        target: const EveryoneMention(),
        body: text.substring(match.end),
      );
    }

    if (_uuidPattern.hasMatch(keyword)) {
      return (
        target: AgentMention(keyword),
        body: text.substring(match.end),
      );
    }

    return (target: const NoMention(), body: text);
  }

  /// Reserved recipient keywords that should bypass @file suggestions.
  static const reservedRecipients = {'user', 'everyone'};

  /// Whether a string looks like an agent ID (UUID format).
  static bool isAgentIdPattern(String s) => _uuidPattern.hasMatch(s);
}
