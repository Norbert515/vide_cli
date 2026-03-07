import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// A top-level tab bar for switching between the Agent view (old UI) and
/// the Channel view (new Slack-like UI).
///
/// Renders as two tabs:
/// `[ Agents ] [ # Channel ]`
class ViewTabBar extends StatelessComponent {
  final bool isChannelActive;
  final VoidCallback onSelectAgentView;
  final VoidCallback onSelectChannel;

  const ViewTabBar({
    required this.isChannelActive,
    required this.onSelectAgentView,
    required this.onSelectChannel,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final dimBorder = theme.base.outline.withOpacity(TextOpacity.tertiary);

    return Row(
      children: [
        _Tab(
          label: 'Agents',
          isActive: !isChannelActive,
          onTap: onSelectAgentView,
        ),
        SizedBox(width: 1),
        _Tab(
          label: '# Channel',
          isActive: isChannelActive,
          onTap: onSelectChannel,
        ),
        // Fill remaining space with a dim bottom border
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: BoxBorder(bottom: BorderSide(color: dimBorder)),
            ),
            child: Text(''),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessComponent {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    final textColor = isActive
        ? theme.base.primary
        : theme.base.onSurface.withOpacity(TextOpacity.secondary);
    final borderColor = isActive
        ? theme.base.primary
        : theme.base.outline.withOpacity(TextOpacity.tertiary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          border: BoxBorder(bottom: BorderSide(color: borderColor)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: isActive ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}
