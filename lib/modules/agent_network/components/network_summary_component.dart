import 'package:nocterm/nocterm.dart';
import 'package:parott/modules/agent_network/models/agent_network.dart';
import 'package:parott/constants/text_opacity.dart';

class NetworkSummaryComponent extends StatefulComponent {
  final AgentNetwork network;
  final bool selected;
  final bool showDeleteConfirmation;

  const NetworkSummaryComponent({
    super.key,
    required this.network,
    required this.selected,
    this.showDeleteConfirmation = false,
  });

  @override
  State<NetworkSummaryComponent> createState() => _NetworkSummaryComponentState();
}

class _NetworkSummaryComponentState extends State<NetworkSummaryComponent> {
  @override
  Component build(BuildContext context) {
    return _buildSummary();
  }

  Component _buildSummary() {
    final network = component.network;
    final displayName = network.goal;
    final agentCount = network.agents.length;
    final lastActive = network.lastActiveAt ?? network.createdAt;
    final timeAgo = _formatTimeAgo(lastActive);

    final textColor = component.selected
        ? Colors.white.withOpacity(TextOpacity.secondary)
        : Colors.white.withOpacity(TextOpacity.tertiary);
    final leftBorderColor = component.showDeleteConfirmation
        ? Colors.red
        : component.selected
            ? Colors.blue
            : Color(0xFF222222);

    return Row(
      children: [
        Container(width: 1, height: 2, decoration: BoxDecoration(color: leftBorderColor)),
        Expanded(
          child: Container(
            height: 2,
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: component.showDeleteConfirmation
                ? Text(
                    'Press backspace again to confirm deletion',
                    style: TextStyle(color: Colors.red),
                    overflow: TextOverflow.ellipsis,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '$agentCount agent${agentCount != 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }
}
