/// A git branch entry from the branches API.
class GitBranchInfo {
  final String name;
  final bool isCurrent;
  final bool isRemote;
  final String? upstream;
  final String lastCommit;

  const GitBranchInfo({
    required this.name,
    required this.isCurrent,
    required this.isRemote,
    this.upstream,
    required this.lastCommit,
  });

  factory GitBranchInfo.fromJson(Map<String, dynamic> json) => GitBranchInfo(
        name: json['name'] as String,
        isCurrent: json['is-current'] as bool,
        isRemote: json['is-remote'] as bool,
        upstream: json['upstream'] as String?,
        lastCommit: json['last-commit'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'is-current': isCurrent,
        'is-remote': isRemote,
        if (upstream != null) 'upstream': upstream,
        'last-commit': lastCommit,
      };
}
