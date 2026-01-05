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
