import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('AgentStatus', () {
    group('fromString', () {
      test('parses working', () {
        expect(AgentStatusExtension.fromString('working'), AgentStatus.working);
      });

      test('parses waitingForAgent', () {
        expect(
          AgentStatusExtension.fromString('waitingForAgent'),
          AgentStatus.waitingForAgent,
        );
      });

      test('parses waitingForUser', () {
        expect(
          AgentStatusExtension.fromString('waitingForUser'),
          AgentStatus.waitingForUser,
        );
      });

      test('parses idle', () {
        expect(AgentStatusExtension.fromString('idle'), AgentStatus.idle);
      });

      test('returns null for unknown status', () {
        expect(AgentStatusExtension.fromString('unknown'), isNull);
        expect(AgentStatusExtension.fromString(''), isNull);
        expect(AgentStatusExtension.fromString('WORKING'), isNull);
      });
    });

    group('toStringValue', () {
      test('converts working to string', () {
        expect(AgentStatus.working.toStringValue(), 'working');
      });

      test('converts waitingForAgent to string', () {
        expect(AgentStatus.waitingForAgent.toStringValue(), 'waitingForAgent');
      });

      test('converts waitingForUser to string', () {
        expect(AgentStatus.waitingForUser.toStringValue(), 'waitingForUser');
      });

      test('converts idle to string', () {
        expect(AgentStatus.idle.toStringValue(), 'idle');
      });
    });

    test('round-trips all statuses correctly', () {
      for (final status in AgentStatus.values) {
        final stringValue = status.toStringValue();
        final parsed = AgentStatusExtension.fromString(stringValue);
        expect(parsed, status);
      }
    });
  });
}
