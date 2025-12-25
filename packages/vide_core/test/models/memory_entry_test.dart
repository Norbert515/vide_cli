import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('MemoryEntry', () {
    final createdDate = DateTime(2024, 1, 15, 10, 30, 0);
    final updatedDate = DateTime(2024, 1, 15, 11, 0, 0);

    group('toJson', () {
      test('serializes all fields', () {
        final entry = MemoryEntry(
          key: 'build_command',
          value: 'flutter run -d chrome',
          createdAt: createdDate,
          updatedAt: updatedDate,
        );

        final json = entry.toJson();

        expect(json['key'], 'build_command');
        expect(json['value'], 'flutter run -d chrome');
        expect(json['createdAt'], createdDate.toIso8601String());
        expect(json['updatedAt'], updatedDate.toIso8601String());
      });

      test('serializes null updatedAt', () {
        final entry = MemoryEntry(
          key: 'platform',
          value: 'web',
          createdAt: createdDate,
        );

        final json = entry.toJson();

        expect(json['updatedAt'], isNull);
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = {
          'key': 'build_command',
          'value': 'flutter run -d chrome',
          'createdAt': createdDate.toIso8601String(),
          'updatedAt': updatedDate.toIso8601String(),
        };

        final entry = MemoryEntry.fromJson(json);

        expect(entry.key, 'build_command');
        expect(entry.value, 'flutter run -d chrome');
        expect(entry.createdAt, createdDate);
        expect(entry.updatedAt, updatedDate);
      });

      test('handles missing updatedAt', () {
        final json = {
          'key': 'platform',
          'value': 'web',
          'createdAt': createdDate.toIso8601String(),
        };

        final entry = MemoryEntry.fromJson(json);

        expect(entry.updatedAt, isNull);
      });

      test('handles null updatedAt', () {
        final json = {
          'key': 'platform',
          'value': 'web',
          'createdAt': createdDate.toIso8601String(),
          'updatedAt': null,
        };

        final entry = MemoryEntry.fromJson(json);

        expect(entry.updatedAt, isNull);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final original = MemoryEntry(
          key: 'build_command',
          value: 'flutter run -d chrome',
          createdAt: createdDate,
          updatedAt: updatedDate,
        );

        final copied = original.copyWith();

        expect(copied.key, original.key);
        expect(copied.value, original.value);
        expect(copied.createdAt, original.createdAt);
        expect(copied.updatedAt, original.updatedAt);
      });

      test('updates specified fields', () {
        final original = MemoryEntry(
          key: 'build_command',
          value: 'flutter run -d chrome',
          createdAt: createdDate,
        );

        final newUpdatedAt = DateTime(2024, 1, 16);
        final copied = original.copyWith(
          value: 'flutter run -d ios',
          updatedAt: newUpdatedAt,
        );

        expect(copied.value, 'flutter run -d ios');
        expect(copied.updatedAt, newUpdatedAt);
        // Unchanged
        expect(copied.key, original.key);
        expect(copied.createdAt, original.createdAt);
      });
    });

    test('round-trips through JSON correctly', () {
      final original = MemoryEntry(
        key: 'build_command',
        value: 'flutter run -d chrome',
        createdAt: createdDate,
        updatedAt: updatedDate,
      );

      final json = original.toJson();
      final restored = MemoryEntry.fromJson(json);

      expect(restored.key, original.key);
      expect(restored.value, original.value);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('handles special characters in value', () {
      final entry = MemoryEntry(
        key: 'notes',
        value: 'Line 1\nLine 2\tTabbed\n"Quoted" and \'single\'',
        createdAt: createdDate,
      );

      final json = entry.toJson();
      final restored = MemoryEntry.fromJson(json);

      expect(restored.value, entry.value);
    });
  });
}
