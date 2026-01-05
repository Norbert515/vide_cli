import 'package:claude_sdk/src/utils/html_entity_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlEntityDecoder', () {
    group('decode', () {
      test('decodes &lt; to <', () {
        expect(HtmlEntityDecoder.decode('&lt;div&gt;'), equals('<div>'));
      });

      test('decodes &gt; to >', () {
        expect(HtmlEntityDecoder.decode('a &gt; b'), equals('a > b'));
      });

      test('decodes &quot; to double quote', () {
        expect(
          HtmlEntityDecoder.decode('&quot;hello&quot;'),
          equals('"hello"'),
        );
      });

      test('decodes &apos; to single quote', () {
        expect(HtmlEntityDecoder.decode("it&apos;s"), equals("it's"));
      });

      test('decodes &amp; to &', () {
        expect(HtmlEntityDecoder.decode('a &amp; b'), equals('a & b'));
      });

      test('decodes &amp; last to handle nested entities like &amp;quot;', () {
        // &amp;quot; should become &quot; not "
        // This is the correct behavior - we decode literal &amp; entities,
        // not double-encoded entities
        expect(HtmlEntityDecoder.decode('&amp;quot;'), equals('&quot;'));
      });

      test('decodes multiple entities in one string', () {
        expect(
          HtmlEntityDecoder.decode(
            '&lt;a href=&quot;test&quot;&gt;click&lt;/a&gt;',
          ),
          equals('<a href="test">click</a>'),
        );
      });

      test('returns empty string unchanged', () {
        expect(HtmlEntityDecoder.decode(''), equals(''));
      });

      test('returns string without entities unchanged', () {
        expect(HtmlEntityDecoder.decode('hello world'), equals('hello world'));
      });

      test('handles string with only entities', () {
        expect(HtmlEntityDecoder.decode('&lt;&gt;'), equals('<>'));
      });
    });

    group('decodeMap', () {
      test('decodes string values in map', () {
        final input = {'key': '&lt;value&gt;'};
        final result = HtmlEntityDecoder.decodeMap(input);
        expect(result['key'], equals('<value>'));
      });

      test('recursively decodes nested maps', () {
        final input = {
          'outer': {'inner': '&quot;nested&quot;'},
        };
        final result = HtmlEntityDecoder.decodeMap(input);
        expect(result['outer']['inner'], equals('"nested"'));
      });

      test('recursively decodes lists within maps', () {
        final input = {
          'items': ['&lt;first&gt;', '&amp;second'],
        };
        final result = HtmlEntityDecoder.decodeMap(input);
        expect(result['items'], equals(['<first>', '&second']));
      });

      test('preserves non-string values', () {
        final input = {
          'number': 42,
          'boolean': true,
          'null': null,
          'double': 3.14,
        };
        final result = HtmlEntityDecoder.decodeMap(input);
        expect(result['number'], equals(42));
        expect(result['boolean'], equals(true));
        expect(result['null'], isNull);
        expect(result['double'], equals(3.14));
      });

      test('handles empty map', () {
        final result = HtmlEntityDecoder.decodeMap({});
        expect(result, equals({}));
      });

      test('handles deeply nested structure', () {
        final input = {
          'level1': {
            'level2': {
              'level3': ['&lt;deep&gt;'],
            },
          },
        };
        final result = HtmlEntityDecoder.decodeMap(input);
        expect(result['level1']['level2']['level3'][0], equals('<deep>'));
      });
    });

    group('decodeList', () {
      test('decodes string elements', () {
        final input = ['&lt;', '&gt;', '&amp;'];
        final result = HtmlEntityDecoder.decodeList(input);
        expect(result, equals(['<', '>', '&']));
      });

      test('recursively decodes nested maps', () {
        final input = [
          {'key': '&quot;value&quot;'},
        ];
        final result = HtmlEntityDecoder.decodeList(input);
        expect(result[0]['key'], equals('"value"'));
      });

      test('recursively decodes nested lists', () {
        final input = [
          ['&lt;nested&gt;'],
        ];
        final result = HtmlEntityDecoder.decodeList(input);
        expect(result[0][0], equals('<nested>'));
      });

      test('preserves non-string values', () {
        final input = [42, true, null, 3.14];
        final result = HtmlEntityDecoder.decodeList(input);
        expect(result, equals([42, true, null, 3.14]));
      });

      test('handles empty list', () {
        final result = HtmlEntityDecoder.decodeList([]);
        expect(result, equals([]));
      });

      test('handles mixed content', () {
        final input = [
          '&lt;text&gt;',
          42,
          {'nested': '&amp;'},
          ['&apos;'],
          null,
        ];
        final result = HtmlEntityDecoder.decodeList(input);
        expect(result[0], equals('<text>'));
        expect(result[1], equals(42));
        expect(result[2]['nested'], equals('&'));
        expect(result[3][0], equals("'"));
        expect(result[4], isNull);
      });
    });
  });
}
