import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';

import '../mcp/git/git_client.dart';
import '../mcp/git/git_models.dart';

/// Riverpod provider for GitService, keyed by working directory path.
final gitServiceProvider = Provider.family<GitService, String>((
  ref,
  workingDirectory,
) {
  return GitService(workingDirectory: workingDirectory);
});

/// High-level git service that encapsulates common git workflows.
///
/// Wraps [GitClient] with composite operations like [sync] (pull + push),
/// [mergeToMain], and [createWorktree] with auto-generated paths.
///
/// Usable by both the TUI and REST API without any UI dependencies.
class GitService {
  final String workingDirectory;
  final GitClient _client;

  GitService({required this.workingDirectory})
    : _client = GitClient(workingDirectory: workingDirectory);

  // ---------------------------------------------------------------------------
  // Status & Info
  // ---------------------------------------------------------------------------

  /// Get current repository status.
  Future<GitStatus> status({bool detailed = false}) =>
      _client.status(detailed: detailed);

  /// Get the name of the current branch.
  Future<String> currentBranch() => _client.currentBranch();

  /// List branches. If [all] is true, includes remote branches.
  Future<List<GitBranch>> branches({bool all = false}) =>
      _client.branches(all: all);

  /// List all worktrees.
  Future<List<GitWorktree>> worktrees() => _client.worktreeList();

  /// Check if the working directory is a git repository.
  Future<bool> isGitRepo() async {
    final gitDir = Directory(p.join(workingDirectory, '.git'));
    return gitDir.exists();
  }

  /// Get the number of commits in HEAD that are not in [targetBranch].
  Future<int> commitsAheadOf(String targetBranch) =>
      _client.getCommitsAheadOf(targetBranch);

  /// Get recently checked out branches from reflog.
  Future<List<String>> recentBranches({int limit = 10}) =>
      _client.getRecentBranches(limit: limit);

  // ---------------------------------------------------------------------------
  // Branch operations
  // ---------------------------------------------------------------------------

  /// Checkout an existing branch.
  Future<void> checkout(String branch) => _client.checkout(branch);

  /// Create a new branch and check it out.
  ///
  /// If [fromBranch] is specified, checks out that branch first before
  /// creating the new one.
  Future<void> createAndCheckoutBranch(
    String name, {
    String? fromBranch,
  }) async {
    if (fromBranch != null) {
      await _client.checkout(fromBranch);
    }
    await _client.checkout(name, create: true);
  }

  // ---------------------------------------------------------------------------
  // Remote operations
  // ---------------------------------------------------------------------------

  /// Sync with remote: pull --rebase then push.
  Future<void> sync() async {
    await _client.pull(rebase: true);
    await _client.push();
  }

  /// Merge [featureBranch] into main (or master).
  ///
  /// Determines the main branch name automatically. On failure, attempts
  /// to check out the original feature branch.
  ///
  /// Returns the name of the main branch that was merged into.
  Future<String> mergeToMain(
    String featureBranch, {
    List<GitBranch>? knownBranches,
  }) async {
    final mainBranch = knownBranches?.any((b) => b.name == 'main') == true
        ? 'main'
        : 'master';

    try {
      await _client.checkout(mainBranch);
      await _client.merge(featureBranch);
      return mainBranch;
    } catch (e) {
      // Attempt to return to the feature branch on failure
      try {
        await _client.checkout(featureBranch);
      } catch (_) {}
      rethrow;
    }
  }

  /// Pull from remote.
  Future<String> pull({
    String remote = 'origin',
    String? branch,
    bool rebase = false,
  }) => _client.pull(remote: remote, branch: branch, rebase: rebase);

  /// Push to remote.
  Future<String> push({
    String remote = 'origin',
    String? branch,
    bool setUpstream = false,
  }) => _client.push(remote: remote, branch: branch, setUpstream: setUpstream);

  /// Fetch from remote.
  Future<void> fetch({
    String remote = 'origin',
    bool all = false,
    bool prune = false,
  }) => _client.fetch(remote: remote, all: all, prune: prune);

  /// Merge a branch into the current branch.
  Future<void> merge(String branch, {String? message, bool noCommit = false}) =>
      _client.merge(branch, message: message, noCommit: noCommit);

  /// Abort the current merge.
  Future<void> mergeAbort() => _client.mergeAbort();

  /// Rebase onto another branch.
  Future<void> rebase(String onto) => _client.rebase(onto);

  /// Continue a rebase after resolving conflicts.
  Future<void> rebaseContinue() => _client.rebaseContinue();

  /// Abort the current rebase.
  Future<void> rebaseAbort() => _client.rebaseAbort();

  /// Skip the current patch in a rebase.
  Future<void> rebaseSkip() => _client.rebaseSkip();

  // ---------------------------------------------------------------------------
  // Commit operations
  // ---------------------------------------------------------------------------

  /// Create a commit.
  Future<void> commit(String message, {bool all = false, bool amend = false}) =>
      _client.commit(message, all: all, amend: amend);

  /// Stage files. Use ['.'] to stage all.
  Future<void> stage(List<String> files) => _client.add(files);

  /// Show diff. If [staged] is true, shows staged changes.
  Future<String> diff({bool staged = false, List<String> files = const []}) =>
      _client.diff(staged: staged, files: files);

  /// Get commit log.
  Future<List<GitCommit>> log({int count = 10}) => _client.log(count: count);

  // ---------------------------------------------------------------------------
  // Worktree operations
  // ---------------------------------------------------------------------------

  /// Create a worktree with a new branch.
  ///
  /// Auto-generates the worktree path as `../<repo-name>-<branchName>`.
  /// Returns the absolute path to the new worktree.
  Future<String> createWorktree(
    String branchName, {
    String? baseBranch,
    bool createBranch = true,
  }) async {
    final repoName = p.basename(workingDirectory);
    final worktreePath = p.join(
      p.dirname(workingDirectory),
      '$repoName-$branchName',
    );

    await _client.worktreeAdd(
      worktreePath,
      branch: branchName,
      createBranch: createBranch,
      baseBranch: baseBranch,
    );

    return Directory(worktreePath).absolute.path;
  }

  /// Remove a worktree.
  Future<void> removeWorktree(String worktreePath, {bool force = false}) =>
      _client.worktreeRemove(worktreePath, force: force);

  /// Lock a worktree.
  Future<void> lockWorktree(String worktree, {String? reason}) =>
      _client.worktreeLock(worktree, reason: reason);

  /// Unlock a worktree.
  Future<void> unlockWorktree(String worktree) =>
      _client.worktreeUnlock(worktree);

  /// Check if this repo is a worktree (not the main repo).
  Future<bool> isWorktree() => _client.isWorktree();

  /// Get the path to the main repository.
  Future<String> mainRepoPath() => _client.getMainRepoPath();

  // ---------------------------------------------------------------------------
  // Stash operations
  // ---------------------------------------------------------------------------

  /// Stash current changes.
  Future<void> stash({String? message}) => _client.stashPush(message: message);

  /// Pop the most recent stash (or at [index]).
  Future<void> stashPop({int? index}) => _client.stashPop(index: index);

  /// Apply a stash without removing it.
  Future<void> stashApply({int? index}) => _client.stashApply(index: index);

  /// Drop a stash entry.
  Future<void> stashDrop({int? index}) => _client.stashDrop(index: index);

  /// Clear all stashes.
  Future<void> stashClear() => _client.stashClear();

  /// List all stashes.
  Future<String> stashList() => _client.stashList();

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Execute a raw git command.
  Future<String> runCommand(List<String> args) => _client.runCommand(args);
}
