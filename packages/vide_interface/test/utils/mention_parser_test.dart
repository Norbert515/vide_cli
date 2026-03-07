import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

void main() {
  group('MentionParser.parse', () {
    test('@user with body', () {
      final result = MentionParser.parse('@user Hello');
      expect(result.target, isA<UserMention>());
      expect(result.body, 'Hello');
    });

    test('@everyone with body', () {
      final result = MentionParser.parse('@everyone Status update');
      expect(result.target, isA<EveryoneMention>());
      expect(result.body, 'Status update');
    });

    test('@uuid with body', () {
      final result = MentionParser.parse(
        '@a7cfabaf-577b-42c9-b05d-c81b78bdfbde Please implement...',
      );
      expect(result.target, isA<AgentMention>());
      expect(
        (result.target as AgentMention).agentId,
        'a7cfabaf-577b-42c9-b05d-c81b78bdfbde',
      );
      expect(result.body, 'Please implement...');
    });

    test('leading whitespace is trimmed', () {
      final result = MentionParser.parse('  @user');
      expect(result.target, isA<UserMention>());
      expect(result.body, '');
    });

    test('mid-message @user returns NoMention', () {
      final result = MentionParser.parse('Hello @user');
      expect(result.target, isA<NoMention>());
      expect(result.body, 'Hello @user');
    });

    test('@username (not exact "user") returns NoMention', () {
      final result = MentionParser.parse('@username');
      expect(result.target, isA<NoMention>());
      expect(result.body, '@username');
    });

    test('@override returns NoMention', () {
      final result = MentionParser.parse('@override');
      expect(result.target, isA<NoMention>());
      expect(result.body, '@override');
    });

    test('@src/lib/file.dart returns NoMention', () {
      // The slash stops the regex from matching a valid keyword/UUID
      final result = MentionParser.parse('@src/lib/file.dart');
      expect(result.target, isA<NoMention>());
      expect(result.body, '@src/lib/file.dart');
    });

    test('empty string returns NoMention', () {
      final result = MentionParser.parse('');
      expect(result.target, isA<NoMention>());
      expect(result.body, '');
    });

    test('@user with no body', () {
      final result = MentionParser.parse('@user');
      expect(result.target, isA<UserMention>());
      expect(result.body, '');
    });

    test('@everyone with no body', () {
      final result = MentionParser.parse('@everyone');
      expect(result.target, isA<EveryoneMention>());
      expect(result.body, '');
    });

    test('@user with multi-line body', () {
      final result = MentionParser.parse('@user Line one\nLine two');
      expect(result.target, isA<UserMention>());
      expect(result.body, 'Line one\nLine two');
    });

    test('@everyoneelse returns NoMention (not exact match)', () {
      final result = MentionParser.parse('@everyoneelse');
      expect(result.target, isA<NoMention>());
    });

    test('just @ returns NoMention', () {
      final result = MentionParser.parse('@');
      expect(result.target, isA<NoMention>());
    });

    test('@user with extra whitespace before body', () {
      // The whitespace boundary between @mention and body is consumed.
      final result = MentionParser.parse('@user   padded body');
      expect(result.target, isA<UserMention>());
      expect(result.body, 'padded body');
    });
  });

  group('MentionParser.isAgentIdPattern', () {
    test('valid UUID returns true', () {
      expect(
        MentionParser.isAgentIdPattern(
          'a7cfabaf-577b-42c9-b05d-c81b78bdfbde',
        ),
        isTrue,
      );
    });

    test('non-UUID returns false', () {
      expect(MentionParser.isAgentIdPattern('user'), isFalse);
      expect(MentionParser.isAgentIdPattern('not-a-uuid'), isFalse);
      expect(MentionParser.isAgentIdPattern(''), isFalse);
    });
  });

  group('MentionParser.reservedRecipients', () {
    test('contains user and everyone', () {
      expect(MentionParser.reservedRecipients, contains('user'));
      expect(MentionParser.reservedRecipients, contains('everyone'));
    });
  });
}
