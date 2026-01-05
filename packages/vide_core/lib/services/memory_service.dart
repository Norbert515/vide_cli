import 'dart:convert';
import 'dart:io';

import '../models/memory_entry.dart';
import 'vide_config_manager.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';

/// Provider for the global MemoryService instance.
///
/// There is exactly one MemoryService in the runtime.
/// The MCP server wraps this service and scopes it to a working directory.
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService(configManager: ref.watch(videConfigManagerProvider));
});

/// Service for storing and retrieving memory entries.
///
/// This service handles file-based persistence of memory entries,
/// scoped by project path. Each project has its own memory storage file.
class MemoryService {
  MemoryService({required VideConfigManager configManager})
    : _configManager = configManager;

  final VideConfigManager _configManager;

  /// Gets the memory file path for a given project.
  String _getMemoryFilePath(String projectPath) {
    final storageDir = _configManager.getProjectStorageDir(projectPath);
    return path.join(storageDir, 'memory.json');
  }

  /// Loads all memory entries for a project.
  Future<Map<String, MemoryEntry>> _loadEntries(String projectPath) async {
    final file = File(_getMemoryFilePath(projectPath));
    if (!await file.exists()) {
      return {};
    }

    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final entriesJson = json['entries'] as Map<String, dynamic>? ?? {};

      return entriesJson.map(
        (key, value) =>
            MapEntry(key, MemoryEntry.fromJson(value as Map<String, dynamic>)),
      );
    } catch (e) {
      // If there's an error reading the file, return empty map
      return {};
    }
  }

  /// Saves all memory entries for a project.
  Future<void> _saveEntries(
    String projectPath,
    Map<String, MemoryEntry> entries,
  ) async {
    final filePath = _getMemoryFilePath(projectPath);
    final file = File(filePath);

    // Ensure directory exists
    await file.parent.create(recursive: true);

    final json = jsonEncode({
      'entries': entries.map((key, entry) => MapEntry(key, entry.toJson())),
    });
    await file.writeAsString(json);
  }

  /// Saves a memory entry for a project.
  ///
  /// If an entry with the same key exists, it will be updated.
  Future<void> save(String projectPath, String key, String value) async {
    final entries = await _loadEntries(projectPath);
    final now = DateTime.now();

    if (entries.containsKey(key)) {
      entries[key] = entries[key]!.copyWith(value: value, updatedAt: now);
    } else {
      entries[key] = MemoryEntry(key: key, value: value, createdAt: now);
    }

    await _saveEntries(projectPath, entries);
  }

  /// Retrieves a memory entry by key for a project.
  ///
  /// Returns null if the key doesn't exist.
  Future<MemoryEntry?> retrieve(String projectPath, String key) async {
    final entries = await _loadEntries(projectPath);
    return entries[key];
  }

  /// Deletes a memory entry by key for a project.
  ///
  /// Returns true if the entry was deleted, false if it didn't exist.
  Future<bool> delete(String projectPath, String key) async {
    final entries = await _loadEntries(projectPath);

    if (!entries.containsKey(key)) {
      return false;
    }

    entries.remove(key);
    await _saveEntries(projectPath, entries);
    return true;
  }

  /// Lists all memory entries for a project.
  Future<List<MemoryEntry>> list(String projectPath) async {
    final entries = await _loadEntries(projectPath);
    return entries.values.toList();
  }

  /// Lists all keys for a project.
  Future<List<String>> listKeys(String projectPath) async {
    final entries = await _loadEntries(projectPath);
    return entries.keys.toList();
  }

  /// Gets all project paths that have memory storage.
  ///
  /// This scans the config directory for all projects with memory files.
  Future<List<String>> getAllProjectPaths() async {
    final configRoot = _configManager.configRoot;
    final projectsDir = Directory(path.join(configRoot, 'projects'));

    if (!await projectsDir.exists()) {
      return [];
    }

    final projectPaths = <String>[];

    await for (final entity in projectsDir.list()) {
      if (entity is Directory) {
        final memoryFile = File(path.join(entity.path, 'memory.json'));
        if (await memoryFile.exists()) {
          // Decode the project path from the directory name
          final encodedPath = path.basename(entity.path);
          final decodedPath = _decodeProjectPath(encodedPath);
          projectPaths.add(decodedPath);
        }
      }
    }

    return projectPaths;
  }

  /// Gets all entries for all projects.
  ///
  /// Returns a map of project path to list of entries.
  Future<Map<String, List<MemoryEntry>>> getAllEntries() async {
    final projectPaths = await getAllProjectPaths();
    final result = <String, List<MemoryEntry>>{};

    for (final projectPath in projectPaths) {
      final entries = await list(projectPath);
      if (entries.isNotEmpty) {
        result[projectPath] = entries;
      }
    }

    return result;
  }

  /// Decodes an encoded project path back to the original path.
  String _decodeProjectPath(String encoded) {
    // The encoding replaces / with -
    // We need to restore the leading / for absolute paths
    if (encoded.startsWith('-')) {
      return encoded.replaceFirst('-', '/').replaceAll('-', '/');
    }
    return encoded.replaceAll('-', '/');
  }
}
