import 'dart:convert';
import '../models/message.dart';

class JsonEncoder {
  const JsonEncoder();

  String encode(Message message) {
    final json = message.toClaudeJson();
    return '${jsonEncode(json)}\n';
  }

  String encodeToolResult({
    required String toolUseId,
    required Map<String, dynamic> result,
  }) {
    final json = {
      'type': 'tool_result',
      'tool_use_id': toolUseId,
      'content': jsonEncode(result),
    };
    return '${jsonEncode(json)}\n';
  }

  String encodeRaw(Map<String, dynamic> json) {
    return '${jsonEncode(json)}\n';
  }
}
