import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:vide_server/routes/filesystem_routes.dart';
import 'package:vide_server/services/server_config.dart';

void main() {
  late Directory testDir;
  late ServerConfig config;

  setUp(() async {
    // Create a temporary test directory structure
    testDir = await Directory.systemTemp.createTemp('filesystem_test_');
    config = ServerConfig(filesystemRoot: testDir.path);

    // Create test files and directories
    await Directory(p.join(testDir.path, 'subdir')).create();
    await Directory(p.join(testDir.path, 'another')).create();
    await File(p.join(testDir.path, 'file1.txt')).writeAsString('content1');
    await File(p.join(testDir.path, 'file2.dart')).writeAsString('content2');
    await File(p.join(testDir.path, 'subdir', 'nested.txt'))
        .writeAsString('nested');
  });

  tearDown(() async {
    await testDir.delete(recursive: true);
  });

  group('listDirectory', () {
    test('lists root directory when no parent specified', () async {
      final request = Request('GET', Uri.parse('http://localhost/filesystem'));
      final response = await listDirectory(request, config);

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      final entries = body['entries'] as List;

      expect(entries.length, 4); // 2 dirs + 2 files

      // Directories should come first
      expect(entries[0]['name'], 'another');
      expect(entries[0]['is-directory'], true);
      expect(entries[1]['name'], 'subdir');
      expect(entries[1]['is-directory'], true);

      // Then files
      expect(entries[2]['name'], 'file1.txt');
      expect(entries[2]['is-directory'], false);
      expect(entries[3]['name'], 'file2.dart');
      expect(entries[3]['is-directory'], false);
    });

    test('lists subdirectory when parent specified', () async {
      final subdir = p.join(testDir.path, 'subdir');
      final request = Request(
        'GET',
        Uri.parse('http://localhost/filesystem?parent=$subdir'),
      );
      final response = await listDirectory(request, config);

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      final entries = body['entries'] as List;

      expect(entries.length, 1);
      expect(entries[0]['name'], 'nested.txt');
      expect(entries[0]['is-directory'], false);
    });

    test('rejects path outside filesystem root', () async {
      final outsidePath = Directory.systemTemp.path;
      final request = Request(
        'GET',
        Uri.parse('http://localhost/filesystem?parent=$outsidePath'),
      );
      final response = await listDirectory(request, config);

      expect(response.statusCode, 403);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'PATH_TRAVERSAL');
    });

    test('rejects path traversal with ..', () async {
      final traversalPath = p.join(testDir.path, 'subdir', '..', '..');
      final request = Request(
        'GET',
        Uri.parse('http://localhost/filesystem?parent=$traversalPath'),
      );
      final response = await listDirectory(request, config);

      expect(response.statusCode, 403);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'PATH_TRAVERSAL');
    });

    test('returns 404 for non-existent directory', () async {
      final nonExistent = p.join(testDir.path, 'nonexistent');
      final request = Request(
        'GET',
        Uri.parse('http://localhost/filesystem?parent=$nonExistent'),
      );
      final response = await listDirectory(request, config);

      expect(response.statusCode, 404);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'NOT_FOUND');
    });

    test('rejects symlinks', () async {
      // Create a symlink
      final symlinkPath = p.join(testDir.path, 'symlink');
      await Link(symlinkPath).create(p.join(testDir.path, 'subdir'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/filesystem?parent=$symlinkPath'),
      );
      final response = await listDirectory(request, config);

      expect(response.statusCode, 403);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'SYMLINK_DENIED');
    });

    test('excludes symlinks from directory listing', () async {
      // Create a symlink in the directory
      final symlinkPath = p.join(testDir.path, 'symlink_file');
      await Link(symlinkPath).create(p.join(testDir.path, 'file1.txt'));

      final request = Request('GET', Uri.parse('http://localhost/filesystem'));
      final response = await listDirectory(request, config);

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      final entries = body['entries'] as List;
      final names = entries.map((e) => e['name']).toList();

      // Symlink should not be in the list
      expect(names, isNot(contains('symlink_file')));
    });
  });

  group('createDirectory', () {
    test('creates new directory', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({'parent': testDir.path, 'name': 'newdir'}),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['path'], p.join(testDir.path, 'newdir'));

      // Verify directory was created
      expect(await Directory(body['path']).exists(), true);
    });

    test('rejects missing parent', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({'name': 'newdir'}),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'INVALID_REQUEST');
    });

    test('rejects missing name', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({'parent': testDir.path}),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'INVALID_REQUEST');
    });

    test('rejects name with path separators', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({'parent': testDir.path, 'name': 'sub/dir'}),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'INVALID_REQUEST');
    });

    test('rejects name with ..', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({'parent': testDir.path, 'name': '..'}),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'INVALID_REQUEST');
    });

    test('rejects parent outside filesystem root', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({
          'parent': Directory.systemTemp.path,
          'name': 'newdir',
        }),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 403);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'PATH_TRAVERSAL');
    });

    test('returns 404 for non-existent parent', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({
          'parent': p.join(testDir.path, 'nonexistent'),
          'name': 'newdir',
        }),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 404);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'NOT_FOUND');
    });

    test('returns 409 when directory already exists', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: jsonEncode({'parent': testDir.path, 'name': 'subdir'}),
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 409);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'ALREADY_EXISTS');
    });

    test('rejects invalid JSON', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/filesystem'),
        body: 'not json',
      );
      final response = await createDirectory(request, config);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['code'], 'INVALID_REQUEST');
    });
  });
}
