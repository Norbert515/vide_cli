/// Filesystem browsing routes for GUI file picker.
///
/// Provides endpoints to browse and create directories within a configured
/// root directory. All operations are restricted to within the filesystem-root
/// to prevent path traversal attacks.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import '../services/server_config.dart';

final _log = Logger('FilesystemRoutes');

/// GET /api/v1/filesystem - List directory contents
///
/// Query params:
///   parent: string (optional) - path to list children of; null/omitted = server root
///
/// Returns:
/// ```json
/// {
///   "entries": [
///     {"name": "src", "path": "/Users/chris/myproject/src", "is-directory": true},
///     {"name": "main.dart", "path": "/Users/chris/myproject/main.dart", "is-directory": false}
///   ]
/// }
/// ```
Future<Response> listDirectory(Request request, ServerConfig config) async {
  final parentParam = request.url.queryParameters['parent'];
  final rootPath = p.canonicalize(config.filesystemRoot);

  // Use filesystem root if no parent specified
  final targetPath = parentParam?.trim().isNotEmpty == true
      ? p.canonicalize(parentParam!)
      : rootPath;

  _log.fine('GET /filesystem: parent=$parentParam, resolved=$targetPath');

  // Security: Validate path is within filesystem root
  if (!_isWithinRoot(targetPath, rootPath)) {
    _log.warning(
      'Path traversal attempt: $targetPath is outside root $rootPath',
    );
    return Response.forbidden(
      jsonEncode({
        'error': 'Path is outside allowed filesystem root',
        'code': 'PATH_TRAVERSAL',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Check if path exists and is a directory (without following symlinks)
  final targetType = FileSystemEntity.typeSync(targetPath, followLinks: false);

  if (targetType == FileSystemEntityType.link) {
    _log.warning('Symlink access denied: $targetPath');
    return Response.forbidden(
      jsonEncode({
        'error': 'Symlinks are not allowed',
        'code': 'SYMLINK_DENIED',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (targetType != FileSystemEntityType.directory) {
    return Response.notFound(
      jsonEncode({
        'error': 'Directory not found: $targetPath',
        'code': 'NOT_FOUND',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final dir = Directory(targetPath);
  final entries = <Map<String, dynamic>>[];

  await for (final entity in dir.list(followLinks: false)) {
    final entityType = FileSystemEntity.typeSync(
      entity.path,
      followLinks: false,
    );

    // Skip symlinks entirely
    if (entityType == FileSystemEntityType.link) {
      continue;
    }

    final name = p.basename(entity.path);
    final isDirectory = entityType == FileSystemEntityType.directory;

    entries.add({
      'name': name,
      'path': entity.path,
      'is-directory': isDirectory,
    });
  }

  // Sort: directories first, then alphabetically by name
  entries.sort((a, b) {
    final aIsDir = a['is-directory'] as bool;
    final bIsDir = b['is-directory'] as bool;
    if (aIsDir != bIsDir) {
      return aIsDir ? -1 : 1;
    }
    return (a['name'] as String).toLowerCase().compareTo(
      (b['name'] as String).toLowerCase(),
    );
  });

  _log.fine('Listed ${entries.length} entries in $targetPath');

  return Response.ok(
    jsonEncode({'entries': entries}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// POST /api/v1/filesystem - Create new folder
///
/// Request body:
/// ```json
/// {
///   "parent": "/Users/chris/projects",
///   "name": "new-project"
/// }
/// ```
///
/// Returns:
/// ```json
/// {
///   "path": "/Users/chris/projects/new-project"
/// }
/// ```
Future<Response> createDirectory(Request request, ServerConfig config) async {
  final body = await request.readAsString();

  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    _log.warning('Invalid JSON in filesystem request: $e');
    return Response.badRequest(
      body: jsonEncode({
        'error': 'Invalid JSON body',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final parent = json['parent'] as String?;
  final name = json['name'] as String?;

  if (parent == null || parent.trim().isEmpty) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'parent is required',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (name == null || name.trim().isEmpty) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'name is required',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Validate name doesn't contain path separators
  if (name.contains('/') || name.contains('\\') || name.contains('..')) {
    return Response.badRequest(
      body: jsonEncode({
        'error': 'Invalid directory name',
        'code': 'INVALID_REQUEST',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final rootPath = p.canonicalize(config.filesystemRoot);
  final parentPath = p.canonicalize(parent);
  final newPath = p.join(parentPath, name);
  final canonicalNewPath = p.canonicalize(newPath);

  _log.fine(
    'POST /filesystem: parent=$parent, name=$name, resolved=$canonicalNewPath',
  );

  // Security: Validate parent and new path are within filesystem root
  if (!_isWithinRoot(parentPath, rootPath)) {
    _log.warning(
      'Path traversal attempt: $parentPath is outside root $rootPath',
    );
    return Response.forbidden(
      jsonEncode({
        'error': 'Parent path is outside allowed filesystem root',
        'code': 'PATH_TRAVERSAL',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (!_isWithinRoot(canonicalNewPath, rootPath)) {
    _log.warning(
      'Path traversal attempt: $canonicalNewPath is outside root $rootPath',
    );
    return Response.forbidden(
      jsonEncode({
        'error': 'New path is outside allowed filesystem root',
        'code': 'PATH_TRAVERSAL',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Check parent exists and is a directory (without following symlinks)
  final parentType = FileSystemEntity.typeSync(parentPath, followLinks: false);

  if (parentType == FileSystemEntityType.link) {
    return Response.forbidden(
      jsonEncode({
        'error': 'Symlinks are not allowed',
        'code': 'SYMLINK_DENIED',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (parentType != FileSystemEntityType.directory) {
    return Response.notFound(
      jsonEncode({
        'error': 'Parent directory not found: $parentPath',
        'code': 'NOT_FOUND',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Check if target already exists
  if (FileSystemEntity.typeSync(canonicalNewPath, followLinks: false) !=
      FileSystemEntityType.notFound) {
    return Response(
      409, // Conflict
      body: jsonEncode({
        'error': 'Path already exists: $canonicalNewPath',
        'code': 'ALREADY_EXISTS',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Create the directory
  final newDir = Directory(canonicalNewPath);
  await newDir.create();

  _log.info('Created directory: $canonicalNewPath');

  return Response.ok(
    jsonEncode({'path': canonicalNewPath}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Check if a path is within the allowed root directory.
///
/// Both paths should already be canonicalized.
bool _isWithinRoot(String path, String root) {
  // Ensure both paths end consistently for comparison
  final normalizedPath = p.normalize(path);
  final normalizedRoot = p.normalize(root);

  // Path must equal root or start with root + separator
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot${p.separator}');
}
