import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/theme/theme.dart';
import 'git_sidebar.dart';

/// A popup overlay wrapper for GitSidebar.
///
/// Displays the GitSidebar in a centered popup overlay.
/// Use the static [show] method to display the dialog.
/// Press ESC to close the popup.
class GitPopup extends StatelessComponent {
  final String repoPath;
  final void Function(String message)? onSendMessage;
  final void Function(String path)? onSwitchWorktree;

  const GitPopup({
    required this.repoPath,
    this.onSendMessage,
    this.onSwitchWorktree,
    super.key,
  });

  /// Shows the git popup dialog using nocterm's Navigator.showDialog() API.
  static Future<void> show(
    BuildContext context, {
    required String repoPath,
    void Function(String message)? onSendMessage,
    void Function(String path)? onSwitchWorktree,
  }) {
    return Navigator.of(context).showDialog(
      builder: (context) => GitPopup(
        repoPath: repoPath,
        onSendMessage: onSendMessage,
        onSwitchWorktree: onSwitchWorktree,
      ),
      barrierDismissible: true, // ESC closes it
      width: 50,
      height: 30,
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Container(
      width: 50,
      height: 30,
      decoration: BoxDecoration(
        color: theme.base.surface,
        border: BoxBorder.all(color: theme.base.primary),
      ),
      child: GitSidebar(
        focused: true,
        expanded: true,
        repoPath: repoPath,
        width: 48,
        onSendMessage: onSendMessage,
        onSwitchWorktree: onSwitchWorktree,
        onExitRight: () => Navigator.of(context).pop(),
      ),
    );
  }
}
