import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../data/repositories/connection_repository.dart';

part 'files_state.g.dart';

class FilesViewState {
  final String currentPath;
  final String rootPath;
  final List<FileEntry> entries;
  final GitStatusInfo? gitStatus;
  final bool isLoading;
  final String? error;

  const FilesViewState({
    required this.currentPath,
    required this.rootPath,
    this.entries = const [],
    this.gitStatus,
    this.isLoading = false,
    this.error,
  });

  bool get isAtRoot => currentPath == rootPath;

  FilesViewState copyWith({
    String? currentPath,
    String? rootPath,
    List<FileEntry>? entries,
    GitStatusInfo? gitStatus,
    bool clearGitStatus = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FilesViewState(
      currentPath: currentPath ?? this.currentPath,
      rootPath: rootPath ?? this.rootPath,
      entries: entries ?? this.entries,
      gitStatus: clearGitStatus ? null : (gitStatus ?? this.gitStatus),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@riverpod
class FilesNotifier extends _$FilesNotifier {
  @override
  FilesViewState build(String sessionWorkingDirectory) {
    _load(sessionWorkingDirectory);
    return FilesViewState(
      currentPath: sessionWorkingDirectory,
      rootPath: sessionWorkingDirectory,
      isLoading: true,
    );
  }

  Future<void> _load(String path) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final client = ref.read(connectionRepositoryProvider).client;
    if (client == null) {
      state = state.copyWith(isLoading: false, error: 'Not connected');
      return;
    }

    try {
      final results = await Future.wait([
        client.listDirectory(parent: path),
        client.gitStatus(state.rootPath, detailed: true),
      ]);

      final entries = results[0] as List<FileEntry>;
      // Sort: directories first, then alphabetical
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      state = state.copyWith(
        currentPath: path,
        entries: entries,
        gitStatus: results[1] as GitStatusInfo,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> navigateTo(String path) async => _load(path);

  Future<void> navigateUp() async {
    if (state.isAtRoot) return;
    var path = state.currentPath;
    // Strip trailing slashes
    while (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return;
    final parent = path.substring(0, lastSlash);
    await _load(parent);
  }

  Future<void> refresh() async => _load(state.currentPath);
}
