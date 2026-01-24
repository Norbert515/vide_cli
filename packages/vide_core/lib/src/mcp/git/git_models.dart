class GitStatus {
  final String branch;
  final bool hasChanges;
  final List<String> modifiedFiles;
  final List<String> untrackedFiles;
  final List<String> stagedFiles;
  final int ahead;
  final int behind;

  GitStatus({
    required this.branch,
    required this.hasChanges,
    required this.modifiedFiles,
    required this.untrackedFiles,
    required this.stagedFiles,
    required this.ahead,
    required this.behind,
  });
}

class GitCommit {
  final String hash;
  final String author;
  final String message;
  final DateTime date;

  GitCommit({
    required this.hash,
    required this.author,
    required this.message,
    required this.date,
  });
}

class GitWorktree {
  final String path;
  final String branch;
  final String commit;
  final bool isLocked;
  final String? lockReason;

  GitWorktree({
    required this.path,
    required this.branch,
    required this.commit,
    required this.isLocked,
    this.lockReason,
  });
}

class GitBranch {
  final String name;
  final bool isCurrent;
  final bool isRemote;
  final String? upstream;
  final String lastCommit;

  GitBranch({
    required this.name,
    required this.isCurrent,
    required this.isRemote,
    this.upstream,
    required this.lastCommit,
  });
}

/// Represents a git repository discovered in multi-repo mode.
class GitRepository {
  final String path;
  final String name;

  const GitRepository({required this.path, required this.name});
}
