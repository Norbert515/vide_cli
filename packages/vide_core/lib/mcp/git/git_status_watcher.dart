import 'dart:async';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;
import 'git_client.dart';
import 'git_models.dart';

/// Watches a git repository for changes and streams GitStatus updates.
///
/// Uses file system watchers on both the working tree and .git/ directory,
/// with 300ms debouncing to prevent excessive git status calls.
class GitStatusWatcher {
  final String repoPath;
  final GitClient _gitClient;

  DirectoryWatcher? _workingTreeWatcher;
  DirectoryWatcher? _dotGitWatcher;
  StreamSubscription? _workingTreeSubscription;
  StreamSubscription? _dotGitSubscription;

  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  final _statusController = StreamController<GitStatus>.broadcast();
  Stream<GitStatus> get statusStream => _statusController.stream;

  bool _isDisposed = false;

  GitStatusWatcher({required this.repoPath})
    : _gitClient = GitClient(workingDirectory: repoPath);

  /// Starts watching the repository for changes.
  /// Call this after construction to begin receiving status updates.
  Future<void> start() async {
    if (_isDisposed) return;

    // Emit initial status
    await _refreshStatus();

    // Watch working tree (exclude .git/)
    _workingTreeWatcher = DirectoryWatcher(repoPath);
    _workingTreeSubscription = _workingTreeWatcher!.events
        .where(
          (event) =>
              !event.path.contains('${p.separator}.git${p.separator}') &&
              !event.path.endsWith('${p.separator}.git'),
        )
        .listen(_onFileChange);

    // Watch .git/ directory (exclude lock files)
    final dotGitPath = p.join(repoPath, '.git');
    _dotGitWatcher = DirectoryWatcher(dotGitPath);
    _dotGitSubscription = _dotGitWatcher!.events
        .where((event) => !event.path.endsWith('.lock'))
        .listen(_onFileChange);
  }

  void _onFileChange(WatchEvent event) {
    if (_isDisposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _refreshStatus);
  }

  Future<void> _refreshStatus() async {
    if (_isDisposed) return;

    try {
      final status = await _gitClient.status();
      if (!_isDisposed) {
        _statusController.add(status);
      }
    } catch (e) {
      // Silently ignore errors (repo might be in inconsistent state during git operations)
    }
  }

  /// Manually trigger a status refresh (e.g., after a git operation).
  Future<void> refresh() => _refreshStatus();

  /// Dispose of watchers and close the stream.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _debounceTimer?.cancel();
    await _workingTreeSubscription?.cancel();
    await _dotGitSubscription?.cancel();
    await _statusController.close();
  }
}
