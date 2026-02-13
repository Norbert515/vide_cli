import 'dart:convert';

import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

/// Tests that verify the JSON serialization format used by
/// Session.sendMessage when attachments are present.
///
/// This tests the contract between vide_client and vide_server:
/// the client serializes attachments with kebab-case keys,
/// and the server deserializes them with the same keys.
void main() {
  group('Client-side attachment JSON serialization', () {
    /// Replicates the exact serialization logic from Session.sendMessage.
    Map<String, dynamic> buildUserMessageJson(
      String content, {
      String? agentId,
      List<VideAttachment>? attachments,
    }) {
      return {
        'type': 'user-message',
        'content': content,
        if (agentId != null) 'agent-id': agentId,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments
              .map(
                (a) => {
                  'type': a.type,
                  if (a.filePath != null) 'file-path': a.filePath,
                  if (a.content != null) 'content': a.content,
                  if (a.mimeType != null) 'mime-type': a.mimeType,
                },
              )
              .toList(),
      };
    }

    test('no attachments omits the key', () {
      final json = buildUserMessageJson('Hello');

      expect(json['type'], 'user-message');
      expect(json['content'], 'Hello');
      expect(json.containsKey('attachments'), isFalse);
    });

    test('null attachments omits the key', () {
      final json = buildUserMessageJson('Hello', attachments: null);

      expect(json.containsKey('attachments'), isFalse);
    });

    test('empty attachments list omits the key', () {
      final json = buildUserMessageJson('Hello', attachments: []);

      expect(json.containsKey('attachments'), isFalse);
    });

    test('image file attachment uses kebab-case keys', () {
      final json = buildUserMessageJson(
        'Check this',
        attachments: [VideAttachment.image('/path/to/screenshot.png')],
      );

      expect(json['attachments'], hasLength(1));
      final att = json['attachments'][0] as Map<String, dynamic>;
      expect(att['type'], 'image');
      expect(att['file-path'], '/path/to/screenshot.png');
      expect(att['mime-type'], 'image/png');
      // file-based attachment should not have 'content'
      expect(att.containsKey('content'), isFalse);
    });

    test('base64 image attachment serializes content', () {
      final json = buildUserMessageJson(
        'Pasted',
        attachments: [
          VideAttachment(
            type: 'image',
            content: 'iVBORw0KGgo=',
            mimeType: 'image/png',
          ),
        ],
      );

      final att = json['attachments'][0] as Map<String, dynamic>;
      expect(att['type'], 'image');
      expect(att['content'], 'iVBORw0KGgo=');
      expect(att['mime-type'], 'image/png');
      // base64 attachment should not have 'file-path'
      expect(att.containsKey('file-path'), isFalse);
    });

    test('multiple attachments all serialize', () {
      final json = buildUserMessageJson(
        'Multiple',
        attachments: [
          VideAttachment.image('/a.png'),
          VideAttachment.image('/b.jpg'),
          VideAttachment(
            type: 'image',
            content: 'base64data',
            mimeType: 'image/jpeg',
          ),
        ],
      );

      expect(json['attachments'], hasLength(3));
    });

    test('minimal attachment only has type', () {
      final json = buildUserMessageJson(
        'Minimal',
        attachments: [VideAttachment(type: 'file')],
      );

      final att = json['attachments'][0] as Map<String, dynamic>;
      expect(att.keys, equals(['type']));
      expect(att['type'], 'file');
    });

    test('agent-id is included when provided', () {
      final json = buildUserMessageJson(
        'Hello',
        agentId: 'agent-2',
        attachments: [VideAttachment.image('/a.png')],
      );

      expect(json['agent-id'], 'agent-2');
      expect(json['attachments'], hasLength(1));
    });

    test('survives JSON encode/decode round-trip', () {
      final original = buildUserMessageJson(
        'Round trip',
        attachments: [
          VideAttachment.image('/path/to/img.png'),
          VideAttachment(
            type: 'image',
            content: 'base64==',
            mimeType: 'image/jpeg',
          ),
        ],
      );

      // Simulate network: encode → decode
      final decoded = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;

      expect(decoded['type'], 'user-message');
      expect(decoded['content'], 'Round trip');

      final attachments = decoded['attachments'] as List<dynamic>;
      expect(attachments, hasLength(2));

      final att0 = attachments[0] as Map<String, dynamic>;
      expect(att0['type'], 'image');
      expect(att0['file-path'], '/path/to/img.png');
      expect(att0['mime-type'], 'image/png');

      final att1 = attachments[1] as Map<String, dynamic>;
      expect(att1['type'], 'image');
      expect(att1['content'], 'base64==');
      expect(att1['mime-type'], 'image/jpeg');
    });
  });

  group('Server-side deserialization (simulated)', () {
    /// Simulates UserMessageAttachment.fromJson from vide_server.
    /// We replicate the logic here to verify the contract.
    Map<String, dynamic> simulateServerParse(Map<String, dynamic> clientJson) {
      final type = clientJson['type'] as String;
      final filePath = clientJson['file-path'] as String?;
      final content = clientJson['content'] as String?;
      final mimeType = clientJson['mime-type'] as String?;
      return {
        'type': type,
        'filePath': filePath,
        'content': content,
        'mimeType': mimeType,
      };
    }

    test('file-path maps to filePath', () {
      final parsed = simulateServerParse({
        'type': 'image',
        'file-path': '/path/to/img.png',
        'mime-type': 'image/png',
      });

      expect(parsed['type'], 'image');
      expect(parsed['filePath'], '/path/to/img.png');
      expect(parsed['mimeType'], 'image/png');
      expect(parsed['content'], isNull);
    });

    test('content maps correctly for base64', () {
      final parsed = simulateServerParse({
        'type': 'image',
        'content': 'base64data',
        'mime-type': 'image/jpeg',
      });

      expect(parsed['content'], 'base64data');
      expect(parsed['filePath'], isNull);
    });
  });

  group('End-to-end contract: VideAttachment → client JSON → server parse', () {
    test('VideAttachment.image file path round-trip', () {
      // 1. TUI creates attachment
      final attachment = VideAttachment.image('/screenshots/test.png');

      // 2. Client serializes (Session.sendMessage logic)
      final clientAttJson = {
        'type': attachment.type,
        if (attachment.filePath != null) 'file-path': attachment.filePath,
        if (attachment.content != null) 'content': attachment.content,
        if (attachment.mimeType != null) 'mime-type': attachment.mimeType,
      };

      // 3. Simulate network transfer
      final wireJson =
          jsonDecode(jsonEncode(clientAttJson)) as Map<String, dynamic>;

      // 4. Server deserializes (UserMessageAttachment.fromJson logic)
      final serverType = wireJson['type'] as String;
      final serverFilePath = wireJson['file-path'] as String?;
      final serverContent = wireJson['content'] as String?;
      final serverMimeType = wireJson['mime-type'] as String?;

      // 5. Server creates VideAttachment for LocalVideSession
      final serverAttachment = VideAttachment(
        type: serverType,
        filePath: serverFilePath,
        content: serverContent,
        mimeType: serverMimeType,
      );

      // 6. Verify all fields match the original
      expect(serverAttachment.type, attachment.type);
      expect(serverAttachment.filePath, attachment.filePath);
      expect(serverAttachment.content, attachment.content);
      expect(serverAttachment.mimeType, attachment.mimeType);
    });

    test('VideAttachment base64 round-trip', () {
      final attachment = VideAttachment(
        type: 'image',
        content: 'iVBORw0KGgoAAAANSUhEUgAAAAE=',
        mimeType: 'image/png',
      );

      final clientAttJson = {
        'type': attachment.type,
        if (attachment.filePath != null) 'file-path': attachment.filePath,
        if (attachment.content != null) 'content': attachment.content,
        if (attachment.mimeType != null) 'mime-type': attachment.mimeType,
      };

      final wireJson =
          jsonDecode(jsonEncode(clientAttJson)) as Map<String, dynamic>;

      final serverAttachment = VideAttachment(
        type: wireJson['type'] as String,
        filePath: wireJson['file-path'] as String?,
        content: wireJson['content'] as String?,
        mimeType: wireJson['mime-type'] as String?,
      );

      expect(serverAttachment.type, attachment.type);
      expect(serverAttachment.filePath, attachment.filePath);
      expect(serverAttachment.content, attachment.content);
      expect(serverAttachment.mimeType, attachment.mimeType);
    });
  });
}
