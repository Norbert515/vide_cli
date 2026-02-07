import 'package:test/test.dart';
import 'package:vide_interface/vide_interface.dart';

void main() {
  group('PermissionResolvedEvent', () {
    test('has correct wireType', () {
      final event = PermissionResolvedEvent(
        agentId: 'agent-1',
        agentType: 'implementer',
        requestId: 'req-1',
        allow: true,
      );

      expect(event.wireType, 'permission-resolved');
    });

    test('serializes to correct dataFields', () {
      final event = PermissionResolvedEvent(
        agentId: 'agent-1',
        agentType: 'implementer',
        requestId: 'req-1',
        allow: true,
        message: 'User approved',
      );

      final fields = event.dataFields();
      expect(fields['request-id'], 'req-1');
      expect(fields['allow'], true);
      expect(fields['message'], 'User approved');
    });

    test('omits null message from dataFields', () {
      final event = PermissionResolvedEvent(
        agentId: 'agent-1',
        agentType: 'implementer',
        requestId: 'req-1',
        allow: false,
      );

      final fields = event.dataFields();
      expect(fields.containsKey('message'), isFalse);
    });
  });
}
