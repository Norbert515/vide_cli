import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';
import 'git_status_watcher.dart';
import 'git_models.dart';

/// Provider for GitStatusWatcher instances, keyed by repository path.
/// Uses autoDispose to clean up watchers when no longer needed.
final gitStatusWatcherProvider = Provider.family
    .autoDispose<GitStatusWatcher, String>((ref, repoPath) {
      final watcher = GitStatusWatcher(repoPath: repoPath);

      // Start watching asynchronously
      watcher.start();

      // Cleanup on dispose
      ref.onDispose(() {
        watcher.dispose();
      });

      return watcher;
    });

/// Stream provider for GitStatus updates, keyed by repository path.
/// Automatically disposes when no UI is subscribed.
final gitStatusStreamProvider = StreamProvider.family
    .autoDispose<GitStatus, String>((ref, repoPath) {
      final watcher = ref.watch(gitStatusWatcherProvider(repoPath));
      return watcher.statusStream;
    });

/// Discovers git repositories in immediate subdirectories of the given path.
final childRepositoriesProvider = FutureProvider.family<List<GitRepository>, String>((ref, parentPath) async {
  final repos = <GitRepository>[];
  final parentDir = Directory(parentPath);

  if (!await parentDir.exists()) return repos;

  await for (final entity in parentDir.list(followLinks: false)) {
    if (entity is Directory) {
      final gitDir = Directory(p.join(entity.path, '.git'));
      if (await gitDir.exists()) {
        repos.add(GitRepository(
          path: entity.path,
          name: p.basename(entity.path),
        ));
      }
    }
  }

  // Sort alphabetically by name
  repos.sort((a, b) => a.name.compareTo(b.name));
  return repos;
});

/// Checks if the given path is itself a git repository.
final isGitRepoProvider = FutureProvider.family<bool, String>((ref, path) async {
  final gitDir = Directory(p.join(path, '.git'));
  return gitDir.existsSync();
});
