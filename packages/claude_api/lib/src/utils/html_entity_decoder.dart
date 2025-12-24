/// Utility class for decoding HTML entities in text content.
///
/// Claude CLI may encode certain characters as HTML entities (e.g., `<` as `&lt;`).
/// This class provides methods to decode these entities back to their original characters.
class HtmlEntityDecoder {
  HtmlEntityDecoder._();

  /// Decodes HTML entities in a string.
  ///
  /// Handles the following entities:
  /// - `&lt;` → `<`
  /// - `&gt;` → `>`
  /// - `&quot;` → `"`
  /// - `&apos;` → `'`
  /// - `&amp;` → `&`
  ///
  /// Note: `&amp;` is decoded last to correctly handle cases like `&amp;quot;`
  /// which should become `&quot;` (not `"`).
  static String decode(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  /// Recursively decodes HTML entities in a [Map<String, dynamic>] structure.
  ///
  /// String values are decoded, nested maps and lists are processed recursively,
  /// and other values are preserved unchanged.
  static Map<String, dynamic> decodeMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is String) {
        return MapEntry(key, decode(value));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, decodeMap(value));
      } else if (value is List) {
        return MapEntry(key, decodeList(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Recursively decodes HTML entities in a [List].
  ///
  /// String elements are decoded, nested maps and lists are processed recursively,
  /// and other values are preserved unchanged.
  static List<dynamic> decodeList(List<dynamic> list) {
    return list.map((item) {
      if (item is String) {
        return decode(item);
      } else if (item is Map<String, dynamic>) {
        return decodeMap(item);
      } else if (item is List) {
        return decodeList(item);
      }
      return item;
    }).toList();
  }
}
