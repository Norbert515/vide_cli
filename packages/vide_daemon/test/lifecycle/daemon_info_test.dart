import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vide_daemon/vide_daemon.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('daemon_info_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('DaemonInfo', () {
    test('toJson serializes all fields', () {
      final info = DaemonInfo(
        pid: 12345,
        port: 8093,
        host: '100.69.74.9',
        startedAt: DateTime.utc(2026, 2, 15, 10, 30),
        logFile: '/tmp/daemon.log',
      );

      final json = info.toJson();

      expect(json['pid'], 12345);
      expect(json['port'], 8093);
      expect(json['host'], '100.69.74.9');
      expect(json['started_at'], '2026-02-15T10:30:00.000Z');
      expect(json['log_file'], '/tmp/daemon.log');
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'pid': 99999,
        'port': 9000,
        'host': '127.0.0.1',
        'started_at': '2026-01-01T00:00:00.000Z',
        'log_file': '/var/log/daemon.log',
      };

      final info = DaemonInfo.fromJson(json);

      expect(info.pid, 99999);
      expect(info.port, 9000);
      expect(info.host, '127.0.0.1');
      expect(info.startedAt, DateTime.utc(2026, 1, 1));
      expect(info.logFile, '/var/log/daemon.log');
    });

    test('fromJson handles null logFile', () {
      final json = {
        'pid': 1,
        'port': 8080,
        'host': '127.0.0.1',
        'started_at': '2026-01-01T00:00:00.000Z',
        'log_file': null,
      };

      final info = DaemonInfo.fromJson(json);
      expect(info.logFile, isNull);
    });

    test('roundtrip through JSON preserves data', () {
      final original = DaemonInfo(
        pid: 42,
        port: 3000,
        host: '0.0.0.0',
        startedAt: DateTime.utc(2026, 6, 15, 12, 0, 0),
        logFile: '/tmp/test.log',
      );

      final json = original.toJson();
      final restored = DaemonInfo.fromJson(json);

      expect(restored.pid, original.pid);
      expect(restored.port, original.port);
      expect(restored.host, original.host);
      expect(restored.startedAt, original.startedAt);
      expect(restored.logFile, original.logFile);
    });

    test('url getter returns correct URL', () {
      final info = DaemonInfo(
        pid: 1,
        port: 8093,
        host: '100.69.74.9',
        startedAt: DateTime.now(),
      );

      expect(info.url, 'http://100.69.74.9:8093');
    });
  });

  group('DaemonInfo file operations', () {
    test('write creates file with correct content', () {
      final info = DaemonInfo(
        pid: 12345,
        port: 8080,
        host: '127.0.0.1',
        startedAt: DateTime.utc(2026, 2, 15, 10, 30),
        logFile: '/tmp/daemon.log',
      );

      DaemonInfo.write(info, stateDir: tempDir.path);

      final file = File(DaemonInfo.filePath(stateDir: tempDir.path));
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['pid'], 12345);
      expect(json['port'], 8080);
    });

    test('read returns info from file', () {
      final info = DaemonInfo(
        pid: 555,
        port: 9000,
        host: '10.0.0.1',
        startedAt: DateTime.utc(2026, 3, 1),
      );

      DaemonInfo.write(info, stateDir: tempDir.path);
      final read = DaemonInfo.read(stateDir: tempDir.path);

      expect(read, isNotNull);
      expect(read!.pid, 555);
      expect(read.port, 9000);
      expect(read.host, '10.0.0.1');
    });

    test('read returns null when file does not exist', () {
      final read = DaemonInfo.read(stateDir: tempDir.path);
      expect(read, isNull);
    });

    test('delete removes the file', () {
      final info = DaemonInfo(
        pid: 1,
        port: 8080,
        host: '127.0.0.1',
        startedAt: DateTime.now(),
      );

      DaemonInfo.write(info, stateDir: tempDir.path);
      expect(
        File(DaemonInfo.filePath(stateDir: tempDir.path)).existsSync(),
        isTrue,
      );

      DaemonInfo.delete(stateDir: tempDir.path);
      expect(
        File(DaemonInfo.filePath(stateDir: tempDir.path)).existsSync(),
        isFalse,
      );
    });

    test('delete is idempotent when file does not exist', () {
      // Should not throw
      DaemonInfo.delete(stateDir: tempDir.path);
    });
  });
}
