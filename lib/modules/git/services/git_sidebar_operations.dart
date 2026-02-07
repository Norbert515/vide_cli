import 'package:path/path.dart' as p;
import 'package:vide_core/vide_core.dart' show GitClient, GitBranch;

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
/// toast notifications.
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
    final client = GitClient(workingDirectory: repoPath);

    try {
      await client.checkout(branchName);

      // Refresh branches/worktrees to reflect the change
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
    final client = GitClient(workingDirectory: repoPath);

    try {
      // Create worktree path: ../reponame-branchname
      final repoName = p.basename(repoPath);
      final worktreePath =
          p.join(p.dirname(repoPath), '$repoName-$branchName');

      // Create worktree with existing branch (don't create new branch)
      await client.worktreeAdd(
        worktreePath,
        branch: branchName,
        createBranch: false,
      );

      // Auto-switch to the new worktree (only for single-repo mode)
      if (!isMultiRepoMode()) {
        onSwitchWorktree?.call(worktreePath);
      }

      // Refresh branches/worktrees to reflect the change
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

    final client = GitClient(workingDirectory: repoPath);

    // Determine the main branch name (main or master)
    final mainBranch = branches?.any((b) => b.name == 'main') == true
        ? 'main'
        : 'master';

    try {
      // 1. Checkout main
      await client.checkout(mainBranch);

      // 2. Merge the feature branch
      await client.merge(featureBranch);

      onSuccess('Merged to main successfully');

      // Refresh branches/worktrees to reflect the change
      await _refreshAfterOperation(repoPath);
    } catch (e) {
      onError('Merge failed: ${e.toString()}');
      // Try to go back to the feature branch on failure
      try {
        await client.checkout(featureBranch);
      } catch (_) {}
    } finally {
      onLoadingChanged(null);
    }
  }

  /// Sync: fetch + pull --rebase + push.
  Future<void> sync(String repoPath) async {
    onLoadingChanged('sync');

    final client = GitClient(workingDirectory: repoPath);

    try {
      // Pull with rebase first (IntelliJ style)
      await client.pull(rebase: true);

      // Then push local commits
      await client.push();

      onSuccess('Synced successfully');

      // Refresh to reflect the updated state
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

    final client = GitClient(workingDirectory: repoPath);

    try {
      await client.pull();
      onSuccess('Pulled successfully');

      // Refresh to reflect the updated state
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

    final client = GitClient(workingDirectory: repoPath);

    try {
      await client.push();
      onSuccess('Pushed successfully');

      // Refresh to reflect the updated state
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

    final client = GitClient(workingDirectory: repoPath);

    try {
      await client.fetch();
      onSuccess('Fetched successfully');

      // Refresh to reflect the updated state
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

    final client = GitClient(workingDirectory: mainRepoPath);

    try {
      await client.worktreeRemove(worktreePath);
      onSuccess('Worktree removed');

      // Refresh to reflect the updated state
      await onRefreshSingleRepo();
    } catch (e) {
      onError('Failed to remove worktree: ${e.toString()}');
    } finally {
      onLoadingChanged(null);
    }
  }
}
