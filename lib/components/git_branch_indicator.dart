import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/theme/theme.dart';

class GitBranchIndicator extends StatelessComponent {
  final String repoPath;

  const GitBranchIndicator({required this.repoPath, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final gitStatusAsync = context.watch(gitStatusStreamProvider(repoPath));
    final gitStatus = gitStatusAsync.valueOrNull;

    if (gitStatus == null) {
      return SizedBox();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: theme.base.secondary),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '',
            style: TextStyle(color: theme.base.background),
          ),
          Text(
            ' ${gitStatus.branch}',
            style: TextStyle(color: theme.base.background),
          ),
        ],
      ),
    );
  }
}
