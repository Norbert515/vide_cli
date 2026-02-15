import 'dart:io';

import 'package:test/test.dart';
import 'package:vide_daemon/vide_daemon.dart';

void main() {
  group('DaemonLifecycle.shellEscape', () {
    test('returns empty string as quoted empty', () {
      expect(DaemonLifecycle.shellEscape(''), "''");
    });

    test('passes through simple alphanumeric strings', () {
      expect(DaemonLifecycle.shellEscape('hello'), 'hello');
      expect(DaemonLifecycle.shellEscape('abc123'), 'abc123');
    });

    test('passes through paths with dots, slashes, dashes, colons', () {
      expect(
        DaemonLifecycle.shellEscape('/usr/local/bin/vide'),
        '/usr/local/bin/vide',
      );
      expect(
        DaemonLifecycle.shellEscape('/tmp/daemon.log'),
        '/tmp/daemon.log',
      );
      expect(DaemonLifecycle.shellEscape('127.0.0.1:8080'), '127.0.0.1:8080');
    });

    test('quotes strings with spaces', () {
      expect(
        DaemonLifecycle.shellEscape('/path with spaces/file'),
        "'/path with spaces/file'",
      );
    });

    test('escapes single quotes within strings', () {
      expect(
        DaemonLifecycle.shellEscape("it's"),
        "'it'\\''s'",
      );
    });

    test('quotes strings with dollar signs (prevents variable expansion)', () {
      expect(
        DaemonLifecycle.shellEscape(r'$HOME/path'),
        "'\$HOME/path'",
      );
    });

    test('quotes strings with backticks (prevents command substitution)', () {
      expect(
        DaemonLifecycle.shellEscape('`whoami`'),
        "'`whoami`'",
      );
    });

    test('quotes strings with semicolons (prevents command chaining)', () {
      expect(
        DaemonLifecycle.shellEscape('foo; rm -rf /'),
        "'foo; rm -rf /'",
      );
    });

    test('quotes strings with pipes', () {
      expect(
        DaemonLifecycle.shellEscape('foo | bar'),
        "'foo | bar'",
      );
    });

    test('quotes strings with newlines', () {
      expect(
        DaemonLifecycle.shellEscape('line1\nline2'),
        "'line1\nline2'",
      );
    });

    test('handles complex injection attempts', () {
      final malicious = "'; rm -rf / #";
      final escaped = DaemonLifecycle.shellEscape(malicious);
      // The single quote in the input gets escaped as '\'' and
      // the whole thing is wrapped in single quotes:
      // '' + '\'' + ; rm -rf / # + '
      expect(escaped, "''\\''; rm -rf / #'");
    });
  });

  group('ServiceInstaller.validateHost', () {
    test('accepts valid IPv4 addresses', () {
      expect(() => ServiceInstaller.validateHost('127.0.0.1'), returnsNormally);
      expect(() => ServiceInstaller.validateHost('0.0.0.0'), returnsNormally);
      expect(
        () => ServiceInstaller.validateHost('100.69.74.9'),
        returnsNormally,
      );
    });

    test('accepts valid hostnames', () {
      expect(() => ServiceInstaller.validateHost('localhost'), returnsNormally);
      expect(
        () => ServiceInstaller.validateHost('my-host.example.com'),
        returnsNormally,
      );
    });

    test('rejects empty host', () {
      expect(
        () => ServiceInstaller.validateHost(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects host with XML injection characters', () {
      expect(
        () => ServiceInstaller.validateHost('127.0.0.1</string><string>evil'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects host with newlines (systemd injection)', () {
      expect(
        () => ServiceInstaller.validateHost('127.0.0.1\nExecStartPost=/bin/sh'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects host with spaces', () {
      expect(
        () => ServiceInstaller.validateHost('127.0.0.1 --flag'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects host with shell metacharacters', () {
      expect(
        () => ServiceInstaller.validateHost('127.0.0.1;whoami'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ServiceInstaller.validateHost('127.0.0.1|cat /etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ServiceInstaller.validatePath', () {
    test('accepts normal paths', () {
      expect(
        () => ServiceInstaller.validatePath('/usr/local/bin/vide'),
        returnsNormally,
      );
    });

    test('rejects paths with newlines', () {
      expect(
        () => ServiceInstaller.validatePath('/bin/vide\nExecStartPost=/bin/sh'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DaemonInfo.read with corrupt data', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('daemon_info_corrupt_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns null and cleans up on empty file', () {
      final file = File(DaemonInfo.filePath(stateDir: tempDir.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('');

      final result = DaemonInfo.read(stateDir: tempDir.path);
      expect(result, isNull);
      expect(file.existsSync(), isFalse);
    });

    test('returns null and cleans up on invalid JSON', () {
      final file = File(DaemonInfo.filePath(stateDir: tempDir.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{invalid json!!!}');

      final result = DaemonInfo.read(stateDir: tempDir.path);
      expect(result, isNull);
      expect(file.existsSync(), isFalse);
    });

    test('returns null and cleans up on partial JSON', () {
      final file = File(DaemonInfo.filePath(stateDir: tempDir.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{"pid": 123, "port":');

      final result = DaemonInfo.read(stateDir: tempDir.path);
      expect(result, isNull);
      expect(file.existsSync(), isFalse);
    });

    test('returns null and cleans up on wrong JSON type', () {
      final file = File(DaemonInfo.filePath(stateDir: tempDir.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('"just a string"');

      final result = DaemonInfo.read(stateDir: tempDir.path);
      expect(result, isNull);
      expect(file.existsSync(), isFalse);
    });
  });
}
