import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('AgentMetadata', () {
    final testDate = DateTime(2024, 1, 15, 10, 30, 0);

    group('toJson', () {
      test('serializes all fields', () {
        final metadata = AgentMetadata(
          id: 'agent-123',
          name: 'Test Agent',
          type: 'implementer',
          spawnedBy: 'parent-456',
          createdAt: testDate,
          taskName: 'Fix bug',
        );

        final json = metadata.toJson();

        expect(json['id'], 'agent-123');
        expect(json['name'], 'Test Agent');
        expect(json['type'], 'implementer');
        expect(json['spawnedBy'], 'parent-456');
        expect(json['createdAt'], testDate.toIso8601String());
        expect(json['taskName'], 'Fix bug');
      });

      test('serializes null optional fields', () {
        final metadata = AgentMetadata(
          id: 'agent-123',
          name: 'Main',
          type: 'main',
          createdAt: testDate,
        );

        final json = metadata.toJson();

        expect(json['spawnedBy'], isNull);
        expect(json['taskName'], isNull);
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = {
          'id': 'agent-123',
          'name': 'Test Agent',
          'type': 'implementer',
          'spawnedBy': 'parent-456',
          'createdAt': testDate.toIso8601String(),
          'taskName': 'Fix bug',
        };

        final metadata = AgentMetadata.fromJson(json);

        expect(metadata.id, 'agent-123');
        expect(metadata.name, 'Test Agent');
        expect(metadata.type, 'implementer');
        expect(metadata.spawnedBy, 'parent-456');
        expect(metadata.createdAt, testDate);
        expect(metadata.taskName, 'Fix bug');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'agent-123',
          'name': 'Main',
          'type': 'main',
          'createdAt': testDate.toIso8601String(),
        };

        final metadata = AgentMetadata.fromJson(json);

        expect(metadata.spawnedBy, isNull);
        expect(metadata.taskName, isNull);
      });

      test('ignores legacy status field in JSON', () {
        // Old persisted data may have status - ensure we ignore it gracefully
        final json = {
          'id': 'agent-123',
          'name': 'Main',
          'type': 'main',
          'createdAt': testDate.toIso8601String(),
          'status': 'working', // Legacy field - should be ignored
        };

        final metadata = AgentMetadata.fromJson(json);

        // Should parse successfully, status is now runtime-only
        expect(metadata.id, 'agent-123');
        expect(metadata.name, 'Main');
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final original = AgentMetadata(
          id: 'agent-123',
          name: 'Test Agent',
          type: 'implementer',
          spawnedBy: 'parent-456',
          createdAt: testDate,
          taskName: 'Fix bug',
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.name, original.name);
        expect(copied.type, original.type);
        expect(copied.spawnedBy, original.spawnedBy);
        expect(copied.createdAt, original.createdAt);
        expect(copied.taskName, original.taskName);
      });

      test('updates specified fields', () {
        final original = AgentMetadata(
          id: 'agent-123',
          name: 'Test Agent',
          type: 'implementer',
          createdAt: testDate,
        );

        final copied = original.copyWith(
          name: 'Updated Name',
          taskName: 'New Task',
        );

        expect(copied.name, 'Updated Name');
        expect(copied.taskName, 'New Task');
        // Unchanged
        expect(copied.id, original.id);
        expect(copied.type, original.type);
      });
    });

    test('round-trips through JSON correctly', () {
      final original = AgentMetadata(
        id: 'agent-123',
        name: 'Test Agent',
        type: 'implementation',
        spawnedBy: 'parent-456',
        createdAt: testDate,
        taskName: 'Fix bug',
      );

      final json = original.toJson();
      final restored = AgentMetadata.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.spawnedBy, original.spawnedBy);
      expect(restored.createdAt, original.createdAt);
      expect(restored.taskName, original.taskName);
    });
  });
}
