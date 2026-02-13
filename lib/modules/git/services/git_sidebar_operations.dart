import 'package:vide_core/vide_core.dart' show GitService, GitBranch;

/// Callback signatures for git operations.
typedef LoadingCallback = void Function(String? action);
typedef SuccessCallback = void Function(String message);
typedef ErrorCallback = void Function(String message);
typedef RefreshCallback = Future<void> Function();
typedef RefreshRepoCallback = Future<void> Function(String repoPath);
typedef SwitchWorktreeCallback = void Function(String worktreePath);

/// Encapsulates git operations used by GitSidebar.
///
/// Extracted from GitSidebar to reduce file size and improve separation
/// of concerns. All operations use callbacks for state management and
/// toast notifications. Delegates to [GitService] for the actual git work.
class GitSidebarOperations {
  final LoadingCallback onLoadingChanged;
  final SuccessCallback onSuccess;
  final ErrorCallback onError;
  final RefreshCallback onRefreshSingleRepo;
  final RefreshRepoCallback onRefreshMultiRepo;
  final bool Function() isMultiRepoMode;
  final SwitchWorktreeCallback? onSwitchWorktree;

  const GitSidebarOperations({
    required this.onLoadingChanged,
    required this.onSuccess,
    required this.onError,
    required this.onRefreshSingleRepo,
    required this.onRefreshMultiRepo,
    required this.isMultiRepoMode,
    this.onSwitchWorktree,
  });

  Future<void> _refreshAfterOperation(String repoPath) async {
    if (isMultiRepoMode()) {
      await onRefreshMultiRepo(repoPath);
    } else {
      await onRefreshSingleRepo();
    }
  }

  /// Checkout a branch.
  Future<void> checkoutBranch(String branchName, String repoPath) async {
    final git = GitService(workingDirectory: repoPath);

    try {
      await git.checkout(branchName);
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      // TODO: Show error to user (e.g., uncommitted changes)
    }
  }

  /// Create a worktree from an existing branch.
  Future<void> createWorktreeFromBranch(
    String branchName,
    String repoPath,
  ) async {
    final git = GitService(workingDirectory: repoPath);

    try {
      final worktreePath = await git.createWorktree(
        branchName,
        createBranch: false,
      );

      // Auto-switch to the new worktree (only for single-repo mode)
      if (!isMultiRepoMode()) {
        onSwitchWorktree?.call(worktreePath);
      }

      await _refreshAfterOperation(repoPath);
    } catch (e) {
      // TODO: Show error to user
    }
  }

  /// Merge current branch to main.
  /// [branches] is the list of cached branches to determine main vs master.
  Future<void> mergeToMain(
    String featureBranch,
    String repoPath,
    List<GitBranch>? branches,
  ) async {
    onLoadingChanged('merge');

    final git = GitService(workingDirectory: repoPath);

    try {
      await git.mergeToMain(featureBranch, knownBranches: branches);
      onSuccess('Merged to main successfully');
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      onError('Merge failed: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }

  /// Sync: fetch + pull --rebase + push.
  Future<void> sync(String repoPath) async {
    onLoadingChanged('sync');

    final git = GitService(workingDirectory: repoPath);

    try {
      await git.sync();
      onSuccess('Synced successfully');
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      onError('Sync failed: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }

  /// Pull from remote.
  Future<void> pull(String repoPath) async {
    onLoadingChanged('pull');

    final git = GitService(workingDirectory: repoPath);

    try {
      await git.pull();
      onSuccess('Pulled successfully');
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      onError('Pull failed: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }

  /// Push to remote.
  Future<void> push(String repoPath) async {
    onLoadingChanged('push');

    final git = GitService(workingDirectory: repoPath);

    try {
      await git.push();
      onSuccess('Pushed successfully');
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      onError('Push failed: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }

  /// Fetch from remote.
  Future<void> fetch(String repoPath) async {
    onLoadingChanged('fetch');

    final git = GitService(workingDirectory: repoPath);

    try {
      await git.fetch();
      onSuccess('Fetched successfully');
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      onError('Fetch failed: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }

  /// Remove a worktree.
  Future<void> removeWorktree(String worktreePath, String mainRepoPath) async {
    onLoadingChanged('remove');

    final git = GitService(workingDirectory: mainRepoPath);

    try {
      await git.removeWorktree(worktreePath);
      onSuccess('Worktree removed');
      await onRefreshSingleRepo();
    } catch (e) {
      onError('Failed to remove worktree: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }
}
