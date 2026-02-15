import 'dart:convert';

import 'package:codex_sdk/codex_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('JsonRpcMessage.fromJson', () {
    test('parses notification (method, no id)', () {
      final json = {'method': 'turn/started', 'params': {'turn': {}}};
      final msg = JsonRpcMessage.fromJson(json);
      expect(msg, isA<JsonRpcNotification>());
      final notif = msg as JsonRpcNotification;
      expect(notif.method, 'turn/started');
      expect(notif.params, {'turn': {}});
    });

    test('parses request (method + id)', () {
      final json = {
        'method': 'item/commandExecution/requestApproval',
        'id': 5,
        'params': {'command': 'rm -rf /'},
      };
      final msg = JsonRpcMessage.fromJson(json);
      expect(msg, isA<JsonRpcRequest>());
      final req = msg as JsonRpcRequest;
      expect(req.id, 5);
      expect(req.method, 'item/commandExecution/requestApproval');
      expect(req.params['command'], 'rm -rf /');
    });

    test('parses response with result (id + result, no method)', () {
      final json = {
        'id': 0,
        'result': {'userAgent': 'codex/0.98.0'},
      };
      final msg = JsonRpcMessage.fromJson(json);
      expect(msg, isA<JsonRpcResponse>());
      final resp = msg as JsonRpcResponse;
      expect(resp.id, 0);
      expect(resp.result?['userAgent'], 'codex/0.98.0');
      expect(resp.isError, isFalse);
    });

    test('parses error response', () {
      final json = {
        'id': 1,
        'error': {'code': -32600, 'message': 'Invalid Request'},
      };
      final msg = JsonRpcMessage.fromJson(json);
      expect(msg, isA<JsonRpcResponse>());
      final resp = msg as JsonRpcResponse;
      expect(resp.isError, isTrue);
      expect(resp.error!.code, -32600);
      expect(resp.error!.message, 'Invalid Request');
    });

    test('parses response with string id', () {
      final json = {
        'id': 'abc-123',
        'result': {},
      };
      final msg = JsonRpcMessage.fromJson(json);
      expect(msg, isA<JsonRpcResponse>());
      expect((msg as JsonRpcResponse).id, 'abc-123');
    });

    test('notification defaults to empty params', () {
      final json = {'method': 'test/event'};
      final msg = JsonRpcMessage.fromJson(json);
      expect(msg, isA<JsonRpcNotification>());
      expect((msg as JsonRpcNotification).params, isEmpty);
    });
  });

  group('JsonRpcMessage.parseLine', () {
    test('parses valid JSONL', () {
      final line = jsonEncode({'method': 'turn/started', 'params': {}});
      final msg = JsonRpcMessage.parseLine(line);
      expect(msg, isA<JsonRpcNotification>());
    });

    test('returns null for empty line', () {
      expect(JsonRpcMessage.parseLine(''), isNull);
    });

    test('returns null for whitespace', () {
      expect(JsonRpcMessage.parseLine('   \t  '), isNull);
    });

    test('returns null for invalid JSON', () {
      expect(JsonRpcMessage.parseLine('not json'), isNull);
    });

    test('returns null for JSON array', () {
      expect(JsonRpcMessage.parseLine('[1, 2]'), isNull);
    });

    test('trims whitespace before parsing', () {
      final line = '  ${jsonEncode({'method': 'test', 'params': {}})}  ';
      final msg = JsonRpcMessage.parseLine(line);
      expect(msg, isA<JsonRpcNotification>());
    });
  });

  group('JsonRpcError', () {
    test('parses from JSON', () {
      final json = {'code': -32601, 'message': 'Method not found', 'data': 42};
      final error = JsonRpcError.fromJson(json);
      expect(error.code, -32601);
      expect(error.message, 'Method not found');
      expect(error.data, 42);
    });

    test('defaults missing fields', () {
      final error = JsonRpcError.fromJson({});
      expect(error.code, -1);
      expect(error.message, 'Unknown error');
      expect(error.data, isNull);
    });
  });
}
