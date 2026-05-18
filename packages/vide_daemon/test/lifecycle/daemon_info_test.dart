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
        authToken: 'test-token-abc123',
      );

      final json = info.toJson();

      expect(json['pid'], 12345);
      expect(json['port'], 8093);
      expect(json['host'], '100.69.74.9');
      expect(json['started_at'], '2026-02-15T10:30:00.000Z');
      expect(json['log_file'], '/tmp/daemon.log');
      expect(json['auth_token'], 'test-token-abc123');
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'pid': 99999,
        'port': 9000,
        'host': '127.0.0.1',
        'started_at': '2026-01-01T00:00:00.000Z',
        'log_file': '/var/log/daemon.log',
        'auth_token': 'token-xyz',
      };

      final info = DaemonInfo.fromJson(json);

      expect(info.pid, 99999);
      expect(info.port, 9000);
      expect(info.host, '127.0.0.1');
      expect(info.startedAt, DateTime.utc(2026, 1, 1));
      expect(info.logFile, '/var/log/daemon.log');
      expect(info.authToken, 'token-xyz');
    });

    test('fromJson handles null logFile', () {
      final json = {
        'pid': 1,
        'port': 8080,
        'host': '127.0.0.1',
        'started_at': '2026-01-01T00:00:00.000Z',
        'log_file': null,
        'auth_token': 'token',
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
        authToken: 'roundtrip-token',
      );

      final json = original.toJson();
      final restored = DaemonInfo.fromJson(json);

      expect(restored.pid, original.pid);
      expect(restored.port, original.port);
      expect(restored.host, original.host);
      expect(restored.startedAt, original.startedAt);
      expect(restored.logFile, original.logFile);
      expect(restored.authToken, original.authToken);
    });

    test('url getter returns correct URL', () {
      final info = DaemonInfo(
        pid: 1,
        port: 8093,
        host: '100.69.74.9',
        startedAt: DateTime.now(),
        authToken: 'token',
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
        authToken: 'write-test-token',
      );

      DaemonInfo.write(info, stateDir: tempDir.path);

      final file = File(DaemonInfo.filePath(stateDir: tempDir.path));
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['pid'], 12345);
      expect(json['port'], 8080);
      expect(json['auth_token'], 'write-test-token');
    });

    test('read returns info from file', () {
      final info = DaemonInfo(
        pid: 555,
        port: 9000,
        host: '10.0.0.1',
        startedAt: DateTime.utc(2026, 3, 1),
        authToken: 'read-test-token',
      );

      DaemonInfo.write(info, stateDir: tempDir.path);
      final read = DaemonInfo.read(stateDir: tempDir.path);

      expect(read, isNotNull);
      expect(read!.pid, 555);
      expect(read.port, 9000);
      expect(read.host, '10.0.0.1');
      expect(read.authToken, 'read-test-token');
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
        authToken: 'token',
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

  group('Persistent auth token', () {
    test('loadOrGenerateAuthToken creates new token when none exists', () {
      final token = DaemonInfo.loadOrGenerateAuthToken(stateDir: tempDir.path);

      expect(token, isNotEmpty);
      expect(token.length, 64); // 32 bytes = 64 hex chars

      // Verify persisted to file
      final file = File(DaemonInfo.authTokenFilePath(stateDir: tempDir.path));
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), token);
    });

    test('loadOrGenerateAuthToken reuses existing token', () {
      final first = DaemonInfo.loadOrGenerateAuthToken(stateDir: tempDir.path);
      final second = DaemonInfo.loadOrGenerateAuthToken(stateDir: tempDir.path);

      expect(second, first);
    });

    test('loadOrGenerateAuthToken regenerates if file is empty', () {
      final file = File(DaemonInfo.authTokenFilePath(stateDir: tempDir.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('');

      final token = DaemonInfo.loadOrGenerateAuthToken(stateDir: tempDir.path);

      expect(token, isNotEmpty);
      expect(token.length, 64);
    });

    test('generated tokens are unique', () {
      final dir1 = Directory.systemTemp.createTempSync('token_test_1_');
      final dir2 = Directory.systemTemp.createTempSync('token_test_2_');

      try {
        final token1 = DaemonInfo.loadOrGenerateAuthToken(stateDir: dir1.path);
        final token2 = DaemonInfo.loadOrGenerateAuthToken(stateDir: dir2.path);

        expect(token1, isNot(token2));
      } finally {
        dir1.deleteSync(recursive: true);
        dir2.deleteSync(recursive: true);
      }
    });
  });
}
