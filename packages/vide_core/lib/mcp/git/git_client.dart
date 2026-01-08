import 'dart:io';
import 'git_models.dart';
import 'git_exception.dart';

/// A client for executing git operations with typed results.
///
/// Example usage:
/// ```dart
/// final git = GitClient(workingDirectory: '/path/to/repo');
/// final status = await git.status();
/// print('Current branch: ${status.branch}');
/// ```
class GitClient {
  final String? workingDirectory;

  /// Creates a GitClient instance.
  ///
  /// [workingDirectory] - The working directory for git operations.
  /// If null, uses the current directory.
  GitClient({this.workingDirectory});

  // Core operations

  /// Get the current repository status.
  ///
  /// [detailed] - If true, includes detailed file status information.
  Future<GitStatus> status({bool detailed = false}) async {
    final output = await _runGitCommand([
      'status',
      '--porcelain=v1',
      '--branch',
    ]);
    return _parseGitStatus(output);
  }

  /// Create a git commit.
  ///
  /// [message] - The commit message.
  /// [all] - If true, automatically stage all modified files.
  /// [amend] - If true, amend the previous commit.
  Future<void> commit(
    String message, {
    bool all = false,
    bool amend = false,
  }) async {
    final args = ['commit', '-m', message];
    if (all) args.add('-a');
    if (amend) args.add('--amend');
    await _runGitCommand(args);
  }

  /// Stage files for commit.
  ///
  /// [files] - List of file paths to stage. Use ['.'] to stage all files.
  Future<void> add(List<String> files) async {
    await _runGitCommand(['add', ...files]);
  }

  /// Show changes in files.
  ///
  /// [staged] - If true, show staged changes instead of working directory changes.
  /// [files] - Optional list of specific files to diff.
  Future<String> diff({
    bool staged = false,
    List<String> files = const [],
  }) async {
    final args = ['diff'];
    if (staged) args.add('--cached');
    args.addAll(files);
    return await _runGitCommand(args);
  }

  /// Get commit history.
  ///
  /// [count] - Number of commits to retrieve.
  Future<List<GitCommit>> log({int count = 10}) async {
    final output = await _runGitCommand([
      'log',
      '-n',
      count.toString(),
      '--pretty=format:%H|%an|%s|%ai',
    ]);
    return _parseCommits(output);
  }

  /// List branches.
  ///
  /// [all] - If true, include remote branches.
  Future<List<GitBranch>> branches({bool all = false}) async {
    final args = ['branch', '-v', '--no-color'];
    if (all) args.add('-a');
    final output = await _runGitCommand(args);
    return _parseBranches(output);
  }

  /// Create a new branch.
  ///
  /// [name] - The name of the branch to create.
  Future<void> createBranch(String name) async {
    await _runGitCommand(['branch', name]);
  }

  /// Delete a branch.
  ///
  /// [name] - The name of the branch to delete.
  Future<void> deleteBranch(String name) async {
    await _runGitCommand(['branch', '-d', name]);
  }

  /// Switch to a different branch.
  ///
  /// [branch] - The branch name to checkout.
  /// [create] - If true, create the branch before checking it out.
  Future<void> checkout(String branch, {bool create = false}) async {
    final args = ['checkout'];
    if (create) {
      args.addAll(['-b', branch]);
    } else {
      args.add(branch);
    }
    await _runGitCommand(args);
  }

  /// Restore files to their state in the index.
  ///
  /// [files] - List of files to restore.
  Future<void> checkoutFiles(List<String> files) async {
    await _runGitCommand(['checkout', '--', ...files]);
  }

  /// Get the name of the current branch.
  Future<String> currentBranch() async {
    return await _runGitCommand(['branch', '--show-current']);
  }

  // Stash operations

  /// Save local changes to the stash.
  ///
  /// [message] - Optional message describing the stash.
  Future<void> stashPush({String? message}) async {
    final args = ['stash', 'push'];
    if (message != null) {
      args.addAll(['-m', message]);
    }
    await _runGitCommand(args);
  }

  /// Apply and remove the most recent stash.
  ///
  /// [index] - Optional stash index to pop. If null, pops the most recent.
  Future<void> stashPop({int? index}) async {
    final args = ['stash', 'pop'];
    if (index != null) args.add('stash@{$index}');
    await _runGitCommand(args);
  }

  /// Apply a stash without removing it.
  ///
  /// [index] - Optional stash index to apply. If null, applies the most recent.
  Future<void> stashApply({int? index}) async {
    final args = ['stash', 'apply'];
    if (index != null) args.add('stash@{$index}');
    await _runGitCommand(args);
  }

  /// Remove a single stash entry.
  ///
  /// [index] - Optional stash index to drop. If null, drops the most recent.
  Future<void> stashDrop({int? index}) async {
    final args = ['stash', 'drop'];
    if (index != null) args.add('stash@{$index}');
    await _runGitCommand(args);
  }

  /// Remove all stash entries.
  Future<void> stashClear() async {
    await _runGitCommand(['stash', 'clear']);
  }

  /// List all stashes.
  Future<String> stashList() async {
    return await _runGitCommand(['stash', 'list']);
  }

  // Worktree operations

  /// List all worktrees.
  Future<List<GitWorktree>> worktreeList() async {
    final output = await _runGitCommand(['worktree', 'list']);
    return _parseWorktrees(output);
  }

  /// Add a new worktree.
  ///
  /// [path] - The path where the new worktree should be created.
  /// [branch] - Optional branch name for the worktree.
  /// [createBranch] - If true, create a new branch for the worktree.
  /// [baseBranch] - Optional base branch/commit to create the new branch from.
  Future<void> worktreeAdd(
    String path, {
    String? branch,
    bool createBranch = false,
    String? baseBranch,
  }) async {
    final args = ['worktree', 'add'];
    if (createBranch && branch != null) {
      args.addAll(['-b', branch]);
    }
    args.add(path);
    if (!createBranch && branch != null) {
      args.add(branch);
    } else if (baseBranch != null) {
      // When creating a new branch, specify the base commit-ish
      args.add(baseBranch);
    }
    await _runGitCommand(args);
  }

  /// Remove a worktree.
  ///
  /// [worktree] - The path or name of the worktree to remove.
  /// [force] - If true, force removal even with uncommitted changes.
  Future<void> worktreeRemove(String worktree, {bool force = false}) async {
    final args = ['worktree', 'remove'];
    if (force) args.add('--force');
    args.add(worktree);
    await _runGitCommand(args);
  }

  /// Lock a worktree to prevent automatic cleanup.
  ///
  /// [worktree] - The path or name of the worktree to lock.
  /// [reason] - Optional reason for locking.
  Future<void> worktreeLock(String worktree, {String? reason}) async {
    final args = ['worktree', 'lock'];
    if (reason != null) {
      args.addAll(['--reason', reason]);
    }
    args.add(worktree);
    await _runGitCommand(args);
  }

  /// Unlock a worktree.
  ///
  /// [worktree] - The path or name of the worktree to unlock.
  Future<void> worktreeUnlock(String worktree) async {
    await _runGitCommand(['worktree', 'unlock', worktree]);
  }

  /// Check if the current working directory is a git worktree (not the main repo).
  ///
  /// Returns true if this is a worktree, false if it's the main repository.
  /// A worktree has .git as a file pointing to the main repo, not a directory.
  Future<bool> isWorktree() async {
    try {
      final gitDir = await _runGitCommand(['rev-parse', '--git-dir']);
      final gitCommonDir = await _runGitCommand(['rev-parse', '--git-common-dir']);
      // If git-dir != git-common-dir, we're in a worktree
      return gitDir.trim() != gitCommonDir.trim();
    } catch (e) {
      return false;
    }
  }

  /// Get the path to the main repository (the root repo, not a worktree).
  ///
  /// This returns the same path whether called from the main repo or a worktree.
  Future<String> getMainRepoPath() async {
    try {
      final gitCommonDir = await _runGitCommand(['rev-parse', '--git-common-dir']);
      final commonDir = gitCommonDir.trim();
      // git-common-dir returns the .git directory, we need its parent
      if (commonDir == '.git') {
        // We're in the main repo
        return workingDirectory ?? Directory.current.path;
      }
      // For worktrees, commonDir is an absolute path to .git in main repo
      final mainGitDir = Directory(commonDir);
      return mainGitDir.parent.path;
    } catch (e) {
      return workingDirectory ?? Directory.current.path;
    }
  }

  // Remote operations

  /// Download objects and refs from a remote.
  ///
  /// [remote] - The remote to fetch from.
  /// [all] - If true, fetch all remotes.
  /// [prune] - If true, remove remote-tracking references that no longer exist.
  Future<void> fetch({
    String remote = 'origin',
    bool all = false,
    bool prune = false,
  }) async {
    final args = ['fetch'];
    if (all) {
      args.add('--all');
    } else {
      args.add(remote);
    }
    if (prune) args.add('--prune');
    await _runGitCommand(args);
  }

  /// Fetch from and integrate with another repository or local branch.
  ///
  /// [remote] - The remote to pull from.
  /// [branch] - Optional branch name to pull.
  /// [rebase] - If true, use rebase instead of merge.
  Future<String> pull({
    String remote = 'origin',
    String? branch,
    bool rebase = false,
  }) async {
    final args = ['pull'];
    if (rebase) args.add('--rebase');
    args.add(remote);
    if (branch != null) args.add(branch);
    return await _runGitCommand(args);
  }

  /// Join two or more development histories together.
  ///
  /// [branch] - The branch to merge into the current branch.
  /// [message] - Optional merge commit message.
  /// [noCommit] - If true, perform the merge but don't create a commit.
  Future<void> merge(
    String branch, {
    String? message,
    bool noCommit = false,
  }) async {
    final args = ['merge'];
    if (noCommit) args.add('--no-commit');
    if (message != null) args.addAll(['-m', message]);
    args.add(branch);
    await _runGitCommand(args);
  }

  /// Abort the current merge operation.
  Future<void> mergeAbort() async {
    await _runGitCommand(['merge', '--abort']);
  }

  /// Reapply commits on top of another base tip.
  ///
  /// [onto] - The branch to rebase onto.
  Future<void> rebase(String onto) async {
    await _runGitCommand(['rebase', onto]);
  }

  /// Continue a rebase after resolving conflicts.
  Future<void> rebaseContinue() async {
    await _runGitCommand(['rebase', '--continue']);
  }

  /// Abort the current rebase operation.
  Future<void> rebaseAbort() async {
    await _runGitCommand(['rebase', '--abort']);
  }

  /// Skip the current patch in a rebase.
  Future<void> rebaseSkip() async {
    await _runGitCommand(['rebase', '--skip']);
  }

  /// Get recently checked out branches from reflog.
  ///
  /// Returns a list of branch names in order of most recent checkout.
  /// [limit] - Maximum number of recent branches to return.
  Future<List<String>> getRecentBranches({int limit = 10}) async {
    try {
      // Get checkouts from reflog
      final output = await _runGitCommand([
        'reflog',
        'show',
        '--pretty=format:%gs',
        '-n',
        '100', // Check last 100 reflog entries
      ]);

      final recentBranches = <String>[];
      final seenBranches = <String>{};

      for (final line in output.split('\n')) {
        // Look for "checkout: moving from X to Y" pattern
        final match = RegExp(r'checkout: moving from .+ to (.+)').firstMatch(line);
        if (match != null) {
          final branch = match.group(1)!;
          // Skip detached HEAD states (commit hashes)
          if (!branch.contains(RegExp(r'^[0-9a-f]{7,40}$')) &&
              !seenBranches.contains(branch)) {
            seenBranches.add(branch);
            recentBranches.add(branch);
            if (recentBranches.length >= limit) break;
          }
        }
      }

      return recentBranches;
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Get the number of commits in the current branch that are not in the target branch.
  ///
  /// [targetBranch] - The branch to compare against (e.g., 'main', 'master').
  /// Returns the count of commits ahead, or 0 if the branch doesn't exist or on error.
  Future<int> getCommitsAheadOf(String targetBranch) async {
    try {
      // Use rev-list to count commits in HEAD that are not in targetBranch
      final output = await _runGitCommand([
        'rev-list',
        '--count',
        '$targetBranch..HEAD',
      ]);
      return int.tryParse(output.trim()) ?? 0;
    } catch (e) {
      // Branch might not exist or other error
      return 0;
    }
  }

  /// Execute a raw git command with the given arguments.
  ///
  /// This is a lower-level method for when you need direct access to git commands
  /// not covered by the typed methods above.
  Future<String> runCommand(List<String> args) async {
    return await _runGitCommand(args);
  }

  // Private helper methods

  Future<String> _runGitCommand(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw GitException(
        'Git command failed',
        exitCode: result.exitCode,
        stderr: result.stderr.toString().trim(),
        command: args,
      );
    }

    return result.stdout.toString().trim();
  }

  GitStatus _parseGitStatus(String output) {
    final lines = output.split('\n');
    String branch = 'unknown';
    int ahead = 0;
    int behind = 0;
    final modified = <String>[];
    final untracked = <String>[];
    final staged = <String>[];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        final parts = line.substring(3).split('...');
        branch = parts[0];
        if (parts.length > 1 && parts[1].contains('[')) {
          final tracking = RegExp(
            r'\[ahead (\d+)(?:, )?(?:behind (\d+))?\]',
          ).firstMatch(parts[1]);
          if (tracking != null) {
            ahead = int.tryParse(tracking.group(1) ?? '0') ?? 0;
            behind = int.tryParse(tracking.group(2) ?? '0') ?? 0;
          }
        }
      } else if (line.length > 2) {
        final status = line.substring(0, 2);
        final file = line.substring(3);

        if (status[0] != ' ' && status[0] != '?') {
          staged.add(file);
        }
        if (status[1] == 'M') {
          modified.add(file);
        } else if (status == '??') {
          untracked.add(file);
        }
      }
    }

    return GitStatus(
      branch: branch,
      hasChanges:
          modified.isNotEmpty || untracked.isNotEmpty || staged.isNotEmpty,
      modifiedFiles: modified,
      untrackedFiles: untracked,
      stagedFiles: staged,
      ahead: ahead,
      behind: behind,
    );
  }

  List<GitWorktree> _parseWorktrees(String output) {
    final worktrees = <GitWorktree>[];
    final lines = output.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final path = parts[0];
        final commit = parts[1];
        final branch = parts.length > 2
            ? parts.sublist(2).join(' ').replaceAll('[', '').replaceAll(']', '')
            : '';

        final isLocked = line.contains('locked');
        String? lockReason;
        if (isLocked &&
            i + 1 < lines.length &&
            lines[i + 1].contains('locked:')) {
          lockReason = lines[i + 1].split('locked:')[1].trim();
        }

        worktrees.add(
          GitWorktree(
            path: path,
            branch: branch,
            commit: commit,
            isLocked: isLocked,
            lockReason: lockReason,
          ),
        );
      }
    }

    return worktrees;
  }

  List<GitCommit> _parseCommits(String output) {
    if (output.isEmpty) return [];

    final lines = output.split('\n');
    final commits = <GitCommit>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split('|');
      if (parts.length >= 4) {
        commits.add(
          GitCommit(
            hash: parts[0],
            author: parts[1],
            message: parts[2],
            date: DateTime.parse(parts[3]),
          ),
        );
      }
    }

    return commits;
  }

  List<GitBranch> _parseBranches(String output) {
    if (output.isEmpty) return [];

    final lines = output.split('\n');
    final branches = <GitBranch>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final isCurrent = line.startsWith('*');
      // Strip both * (current) and + (diverged from upstream) prefixes
      final cleanLine = line.replaceFirst(RegExp(r'^[*+]\s*'), '').trim();
      final parts = cleanLine.split(RegExp(r'\s+'));

      if (parts.isEmpty) continue;

      final name = parts[0];
      final isRemote = name.startsWith('remotes/');
      final lastCommit = parts.length > 1 ? parts[1] : '';

      // Try to detect upstream branch
      String? upstream;
      if (line.contains('[') && line.contains(']')) {
        final upstreamMatch = RegExp(r'\[([^\]]+)\]').firstMatch(line);
        if (upstreamMatch != null) {
          upstream = upstreamMatch.group(1);
        }
      }

      branches.add(
        GitBranch(
          name: name,
          isCurrent: isCurrent,
          isRemote: isRemote,
          upstream: upstream,
          lastCommit: lastCommit,
        ),
      );
    }

    return branches;
  }
}
