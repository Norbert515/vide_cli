import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/components/shimmer.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/git/git_branch_indicator.dart';
import 'package:vide_cli/theme/theme.dart';

class HomeLogoSection extends StatelessComponent {
  final String repoPath;

  const HomeLogoSection({required this.repoPath, super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final abbreviatedPath = _abbreviatePath(repoPath);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Shimmer(
          delay: Duration(seconds: 4),
          duration: Duration(milliseconds: 1000),
          angle: 0.7,
          highlightWidth: 6,
          child: AsciiText(
            'VIDE',
            font: AsciiFont.standard,
            style: TextStyle(color: theme.base.primary),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Running in ',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            Text(
              ' $abbreviatedPath ',
              style: TextStyle(
                color: theme.base.background,
                backgroundColor: theme.base.primary,
              ),
            ),
            Text(
              ' on ',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
            GitBranchIndicator(repoPath: repoPath),
          ],
        ),
      ],
    );
  }

  static String _abbreviatePath(String fullPath) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && fullPath.startsWith(home)) {
      return '~${fullPath.substring(home.length)}';
    }
    return fullPath;
  }
}
