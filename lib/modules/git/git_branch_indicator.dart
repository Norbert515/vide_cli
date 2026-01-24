import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/theme/theme.dart';

/// Provider to detect if the given repo path is a git worktree.
/// Returns true if the path is a worktree, false if it's the main repo.
final isWorktreeProvider = FutureProvider.family.autoDispose<bool, String>((
  ref,
  repoPath,
) async {
  final client = GitClient(workingDirectory: repoPath);
  return await client.isWorktree();
});

/// Provider to get the main repository path for a given repo path.
/// This returns the same path whether called from the main repo or a worktree.
final mainRepoPathProvider = FutureProvider.family.autoDispose<String, String>((
  ref,
  repoPath,
) async {
  final client = GitClient(workingDirectory: repoPath);
  return await client.getMainRepoPath();
});

class GitBranchIndicator extends StatelessComponent {
  final String repoPath;

  const GitBranchIndicator({required this.repoPath, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final gitStatusAsync = context.watch(gitStatusStreamProvider(repoPath));
    final gitStatus = gitStatusAsync.valueOrNull;
    final isWorktreeAsync = context.watch(isWorktreeProvider(repoPath));
    final isWorktree = isWorktreeAsync.valueOrNull ?? false;

    if (gitStatus == null) {
      return SizedBox();
    }

    final branchDisplay = isWorktree
        ? ' ⎇ ${gitStatus.branch} '
        : ' ${gitStatus.branch} ';

    return Text(
      branchDisplay,
      style: TextStyle(
        color: theme.base.background,
        backgroundColor: theme.base.secondary,
      ),
    );
  }
}
