/// Git repository status information from the git status API.
class GitStatusInfo {
  final String branch;
  final bool hasChanges;
  final List<String> modifiedFiles;
  final List<String> untrackedFiles;
  final List<String> stagedFiles;
  final int ahead;
  final int behind;

  const GitStatusInfo({
    required this.branch,
    required this.hasChanges,
    required this.modifiedFiles,
    required this.untrackedFiles,
    required this.stagedFiles,
    required this.ahead,
    required this.behind,
  });

  factory GitStatusInfo.fromJson(Map<String, dynamic> json) => GitStatusInfo(
        branch: json['branch'] as String,
        hasChanges: json['has-changes'] as bool,
        modifiedFiles:
            (json['modified-files'] as List<dynamic>).cast<String>(),
        untrackedFiles:
            (json['untracked-files'] as List<dynamic>).cast<String>(),
        stagedFiles: (json['staged-files'] as List<dynamic>).cast<String>(),
        ahead: json['ahead'] as int,
        behind: json['behind'] as int,
      );

  Map<String, dynamic> toJson() => {
        'branch': branch,
        'has-changes': hasChanges,
        'modified-files': modifiedFiles,
        'untracked-files': untrackedFiles,
        'staged-files': stagedFiles,
        'ahead': ahead,
        'behind': behind,
      };

  /// All changed files (modified + untracked + staged), deduplicated.
  Set<String> get allChangedFiles => {
        ...modifiedFiles,
        ...untrackedFiles,
        ...stagedFiles,
      };
}
