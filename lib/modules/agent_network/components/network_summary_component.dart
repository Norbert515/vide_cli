import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

class NetworkSummaryComponent extends StatefulComponent {
  final VideSessionInfo sessionInfo;
  final bool selected;
  final bool showDeleteConfirmation;

  const NetworkSummaryComponent({
    super.key,
    required this.sessionInfo,
    required this.selected,
    this.showDeleteConfirmation = false,
  });

  @override
  State<NetworkSummaryComponent> createState() =>
      _NetworkSummaryComponentState();
}

class _NetworkSummaryComponentState extends State<NetworkSummaryComponent> {
  @override
  Component build(BuildContext context) {
    return _buildSummary(context);
  }

  /// Whether the session has unseen activity.
  bool _hasUnseenActivity(VideSessionInfo info) {
    final lastActive = info.lastActiveAt;
    if (lastActive == null) return false;
    final seenAt = info.lastSeenAt;
    if (seenAt == null) return true;
    return lastActive.isAfter(seenAt);
  }

  Component _buildSummary(BuildContext context) {
    final theme = VideTheme.of(context);
    final info = component.sessionInfo;
    final displayName = info.goal;
    final agentCount = info.agentCount;
    final lastActive = info.lastActiveAt ?? info.createdAt;
    final timeAgo = _formatTimeAgo(lastActive);
    final hasUnseen = _hasUnseenActivity(info);

    final textColor = component.selected
        ? theme.base.onSurface.withOpacity(TextOpacity.secondary)
        : hasUnseen
        ? theme.base.onSurface
        : theme.base.onSurface.withOpacity(TextOpacity.tertiary);
    final leftBorderColor = component.showDeleteConfirmation
        ? theme.base.error
        : hasUnseen && !component.selected
        ? theme.base.primary
        : component.selected
        ? theme.base.primary
        : theme.base.outline;

    return Row(
      children: [
        Container(
          width: 1,
          height: 2,
          decoration: BoxDecoration(color: leftBorderColor),
        ),
        Expanded(
          child: Container(
            height: 2,
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: component.showDeleteConfirmation
                ? Text(
                    'Press backspace again to confirm deletion',
                    style: TextStyle(color: theme.base.error),
                    overflow: TextOverflow.ellipsis,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasUnseen)
                            Text(
                              '● ',
                              style: TextStyle(color: theme.base.primary),
                            ),
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: hasUnseen
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '$agentCount agent${agentCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: theme.base.onSurface.withOpacity(
                                TextOpacity.tertiary,
                              ),
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: theme.base.onSurface.withOpacity(
                                TextOpacity.tertiary,
                              ),
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: theme.base.onSurface.withOpacity(
                                TextOpacity.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min${mins != 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days != 1 ? 's' : ''} ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }
}
