import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/modules/agent_network/components/assistant_entry_renderer.dart';
import 'package:vide_cli/modules/agent_network/components/user_message_renderer.dart';
import 'package:vide_core/vide_core.dart';

/// Routes a [ConversationEntry] to the appropriate renderer based on role.
class ConversationEntryRenderer extends StatelessComponent {
  final ConversationEntry entry;
  final String networkId;
  final String agentId;
  final String workingDirectory;

  /// Locally tracked attachments keyed by message text, used as fallback
  /// when [AttachmentContent] is not present in the entry.
  final Map<String, List<VideAttachment>> sentAttachments;

  const ConversationEntryRenderer({
    required this.entry,
    required this.networkId,
    required this.agentId,
    required this.workingDirectory,
    this.sentAttachments = const {},
    super.key,
  });

  @override
  Component build(BuildContext context) {
    if (entry.role == MessageRole.user) {
      return UserMessageRenderer(
        entry: entry,
        sentAttachments: sentAttachments,
      );
    }

    return AssistantEntryRenderer(
      entry: entry,
      networkId: networkId,
      agentId: agentId,
      workingDirectory: workingDirectory,
    );
  }
}
