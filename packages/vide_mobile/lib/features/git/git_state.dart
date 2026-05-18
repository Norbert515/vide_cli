import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../data/repositories/server_registry.dart';

part 'git_state.g.dart';

class GitViewState {
  final String repoPath;
  final GitStatusInfo? status;
  final List<GitCommitInfo> commits;
  final bool isLoading;
  final String? error;

  const GitViewState({
    required this.repoPath,
    this.status,
    this.commits = const [],
    this.isLoading = false,
    this.error,
  });

  GitViewState copyWith({
    String? repoPath,
    GitStatusInfo? status,
    bool clearStatus = false,
    List<GitCommitInfo>? commits,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GitViewState(
      repoPath: repoPath ?? this.repoPath,
      status: clearStatus ? null : (status ?? this.status),
      commits: commits ?? this.commits,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@riverpod
class GitNotifier extends _$GitNotifier {
  @override
  GitViewState build(String repoPath) {
    _load();
    return GitViewState(repoPath: repoPath, isLoading: true);
  }

  Future<void> _load() async {
    await Future<void>.value();

    state = state.copyWith(isLoading: true, clearError: true);

    final registry = ref.read(serverRegistryProvider.notifier);
    final connected = registry.connectedEntries;
    if (connected.isEmpty || connected.first.client == null) {
      state = state.copyWith(isLoading: false, error: 'Not connected');
      return;
    }
    final client = connected.first.client!;

    try {
      final results = await Future.wait([
        client.gitStatus(repoPath, detailed: true),
        client.gitLog(repoPath),
      ]);

      state = state.copyWith(
        status: results[0] as GitStatusInfo,
        commits: results[1] as List<GitCommitInfo>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async => _load();

  Future<void> stageFiles(List<String> files) async {
    final registry = ref.read(serverRegistryProvider.notifier);
    final connected = registry.connectedEntries;
    if (connected.isEmpty || connected.first.client == null) return;
    final client = connected.first.client!;

    try {
      await client.gitStage(repoPath, files);
      await _load();
    } catch (e) {
      state = state.copyWith(error: 'Failed to stage files: $e');
    }
  }
}
