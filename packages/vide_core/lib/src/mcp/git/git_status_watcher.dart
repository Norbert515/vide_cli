import 'dart:async';
import 'git_client.dart';
import 'git_models.dart';

/// Watches a git repository for changes and streams GitStatus updates.
///
/// Uses simple polling instead of file system watchers for better performance.
/// Git's internal caching (and optionally FSMonitor) handles the heavy lifting.
class GitStatusWatcher {
  final String repoPath;
  final Duration pollInterval;
  final GitClient _gitClient;

  Timer? _pollTimer;

  final _statusController = StreamController<GitStatus>.broadcast();
  Stream<GitStatus> get statusStream => _statusController.stream;

  bool _isDisposed = false;
  GitStatus? _lastStatus;

  GitStatusWatcher({
    required this.repoPath,
    this.pollInterval = const Duration(seconds: 5),
  }) : _gitClient = GitClient(workingDirectory: repoPath);

  /// Starts watching the repository for changes.
  /// Call this after construction to begin receiving status updates.
  Future<void> start() async {
    if (_isDisposed) return;

    // Emit initial status
    await _refreshStatus();

    // Start polling timer
    _pollTimer = Timer.periodic(pollInterval, (_) => _refreshStatus());
  }

  Future<void> _refreshStatus() async {
    if (_isDisposed) return;

    try {
      final status = await _gitClient.status();
      if (!_isDisposed) {
        // Only emit if status actually changed
        if (_lastStatus == null || !_statusEquals(_lastStatus!, status)) {
          _lastStatus = status;
          _statusController.add(status);
        }
      }
    } catch (e) {
      // Silently ignore errors (repo might be in inconsistent state during git operations)
    }
  }

  /// Compare two GitStatus objects for equality.
  bool _statusEquals(GitStatus a, GitStatus b) {
    return a.branch == b.branch &&
        a.ahead == b.ahead &&
        a.behind == b.behind &&
        a.hasChanges == b.hasChanges &&
        _listEquals(a.modifiedFiles, b.modifiedFiles) &&
        _listEquals(a.stagedFiles, b.stagedFiles) &&
        _listEquals(a.untrackedFiles, b.untrackedFiles);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Manually trigger a status refresh (e.g., after a git operation).
  Future<void> refresh() => _refreshStatus();

  /// Dispose of watchers and close the stream.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _pollTimer?.cancel();
    await _statusController.close();
  }
}
