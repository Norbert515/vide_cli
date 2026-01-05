import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/conversation_metadata.dart';

/// A single conversation item in the list.
class ConversationListItem extends StatelessWidget {
  final ConversationMetadata conversation;
  final bool isSelected;
  final VoidCallback? onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = conversation.lastModified ?? conversation.timestamp;
    final dateStr = timestamp != null
        ? DateFormat('MMM d, HH:mm').format(timestamp)
        : 'Unknown date';

    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      title: Text(
        conversation.displayText ?? conversation.sessionId.substring(0, 8),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            conversation.sessionId.substring(0, 8),
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
      trailing: conversation.fileSize != null
          ? Text(
              _formatSize(conversation.fileSize!),
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
