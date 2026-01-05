import '../command.dart';

/// Clears the conversation history for the current agent.
///
/// This command sends `/clear` to the Claude Code CLI which handles the
/// actual clearing, then also clears the local UI state.
class ClearCommand extends Command {
  @override
  String get name => 'clear';

  @override
  String get description => 'Clear the conversation history';

  @override
  String get usage => '/clear';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.sendMessage == null) {
      return CommandResult.error('Cannot clear: message sending not available');
    }

    // Send /clear to Claude Code CLI which handles the actual clearing
    context.sendMessage!('/clear');

    // Also clear local UI state
    if (context.clearConversation != null) {
      await context.clearConversation!();
    }

    return CommandResult.success('Conversation cleared');
  }
}
