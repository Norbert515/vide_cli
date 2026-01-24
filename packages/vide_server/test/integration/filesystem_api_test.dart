/// Integration tests for filesystem browsing API.
///
/// Tests verify:
/// 1. Directory listing works correctly
/// 2. Directory creation works correctly
/// 3. Security constraints are enforced
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../test_config.dart';

void main() {
  late Process serverProcess;
  late int port;
  late String baseUrl;
  late Directory testDir;

  setUpAll(() async {
    // Create a temporary test directory with known structure
    testDir = await Directory.systemTemp.createTemp('filesystem_api_test_');
    await Directory(p.join(testDir.path, 'subdir')).create();
    await Directory(p.join(testDir.path, 'another')).create();
    await File(p.join(testDir.path, 'file1.txt')).writeAsString('content1');
    await File(p.join(testDir.path, 'file2.dart')).writeAsString('content2');
    await File(
      p.join(testDir.path, 'subdir', 'nested.txt'),
    ).writeAsString('nested');

    // Create config file with filesystem-root set to our test directory
    final homeDir = Platform.environment['HOME'] ?? Directory.current.path;
    final configDir = Directory(p.join(homeDir, '.vide', 'api'));
    await configDir.create(recursive: true);
    final configFile = File(p.join(configDir.path, 'config.json'));

    // Save existing config if present
    String? existingConfig;
    if (await configFile.exists()) {
      existingConfig = await configFile.readAsString();
    }

    // Write test config
    await configFile.writeAsString(
      jsonEncode({
        'permission-timeout-seconds': 60,
        'auto-approve-all': false,
        'filesystem-root': testDir.path,
      }),
    );

    // Start the server
    port = testPortBase + filesystemTestOffset;
    baseUrl = 'http://127.0.0.1:$port';

    serverProcess = await Process.start('dart', [
      'run',
      'bin/vide_server.dart',
      '--port',
      '$port',
    ], workingDirectory: Directory.current.path);

    // Wait for server to be ready
    final completer = Completer<void>();
    serverProcess.stdout.transform(utf8.decoder).listen((data) {
      stdout.writeln('[Server stdout] $data');
      if (data.contains('Server ready')) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    serverProcess.stderr.transform(utf8.decoder).listen((data) {
      stderr.writeln('[Server stderr] $data');
    });

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Server failed to start'),
    );

    // Restore original config after test (in tearDownAll)
    addTearDown(() async {
      if (existingConfig != null) {
        await configFile.writeAsString(existingConfig);
      } else {
        await configFile.delete();
      }
    });
  });

  tearDownAll(() async {
    serverProcess.kill();
    await serverProcess.exitCode;
    await testDir.delete(recursive: true);
  });

  group('Filesystem API', () {
    group('GET /api/v1/filesystem', () {
      test('lists root directory when no parent specified', () async {
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/filesystem'),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(response.body);
        final entries = body['entries'] as List;

        // Should contain our test files and directories
        final names = entries.map((e) => e['name']).toSet();
        expect(names, contains('subdir'));
        expect(names, contains('another'));
        expect(names, contains('file1.txt'));
        expect(names, contains('file2.dart'));
      });

      test('lists subdirectory when parent specified', () async {
        final subdir = p.join(testDir.path, 'subdir');
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/filesystem?parent=$subdir'),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(response.body);
        final entries = body['entries'] as List;

        expect(entries.length, 1);
        expect(entries[0]['name'], 'nested.txt');
        expect(entries[0]['is-directory'], false);
      });

      test(
        'returns entries sorted (directories first, then alphabetically)',
        () async {
          final response = await http.get(
            Uri.parse('$baseUrl/api/v1/filesystem'),
          );

          expect(response.statusCode, 200);
          final body = jsonDecode(response.body);
          final entries = body['entries'] as List;

          // First two should be directories (alphabetically: another, subdir)
          expect(entries[0]['name'], 'another');
          expect(entries[0]['is-directory'], true);
          expect(entries[1]['name'], 'subdir');
          expect(entries[1]['is-directory'], true);

          // Then files (alphabetically: file1.txt, file2.dart)
          expect(entries[2]['name'], 'file1.txt');
          expect(entries[2]['is-directory'], false);
          expect(entries[3]['name'], 'file2.dart');
          expect(entries[3]['is-directory'], false);
        },
      );

      test('rejects path outside filesystem root', () async {
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/filesystem?parent=/etc'),
        );

        expect(response.statusCode, 403);
        final body = jsonDecode(response.body);
        expect(body['code'], 'PATH_TRAVERSAL');
      });

      test('rejects path traversal with ..', () async {
        final traversalPath = p.join(testDir.path, 'subdir', '..', '..');
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/filesystem?parent=$traversalPath'),
        );

        expect(response.statusCode, 403);
        final body = jsonDecode(response.body);
        expect(body['code'], 'PATH_TRAVERSAL');
      });

      test('returns 404 for non-existent directory', () async {
        final nonExistent = p.join(testDir.path, 'nonexistent');
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/filesystem?parent=$nonExistent'),
        );

        expect(response.statusCode, 404);
        final body = jsonDecode(response.body);
        expect(body['code'], 'NOT_FOUND');
      });
    });

    group('POST /api/v1/filesystem', () {
      test('creates new directory', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/filesystem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'parent': testDir.path, 'name': 'newdir'}),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(response.body);
        expect(body['path'], p.join(testDir.path, 'newdir'));

        // Verify directory was actually created
        expect(await Directory(body['path']).exists(), true);
      });

      test('rejects missing parent', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/filesystem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': 'newdir2'}),
        );

        expect(response.statusCode, 400);
        final body = jsonDecode(response.body);
        expect(body['code'], 'INVALID_REQUEST');
      });

      test('rejects missing name', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/filesystem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'parent': testDir.path}),
        );

        expect(response.statusCode, 400);
        final body = jsonDecode(response.body);
        expect(body['code'], 'INVALID_REQUEST');
      });

      test('rejects parent outside filesystem root', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/filesystem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'parent': '/tmp', 'name': 'newdir3'}),
        );

        expect(response.statusCode, 403);
        final body = jsonDecode(response.body);
        expect(body['code'], 'PATH_TRAVERSAL');
      });

      test('returns 409 when directory already exists', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/filesystem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'parent': testDir.path,
            'name': 'subdir', // Already exists
          }),
        );

        expect(response.statusCode, 409);
        final body = jsonDecode(response.body);
        expect(body['code'], 'ALREADY_EXISTS');
      });

      test('rejects name with path separators', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/filesystem'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'parent': testDir.path, 'name': 'sub/dir'}),
        );

        expect(response.statusCode, 400);
        final body = jsonDecode(response.body);
        expect(body['code'], 'INVALID_REQUEST');
      });
    });
  });
}
