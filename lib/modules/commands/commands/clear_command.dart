import '../command.dart';

/// Clears the conversation history for the current agent.
class ClearCommand extends Command {
  @override
  String get name => 'clear';

  @override
  String get description => 'Clear the conversation history';

  @override
  String get usage => '/clear';

  @override
  Future<CommandResult> execute(CommandContext context, String? arguments) async {
    // TODO: Implement actual clear by calling ClaudeClient.clearConversation()
    // For now, return a placeholder message indicating the command was received

    return CommandResult.success(
      'Conversation cleared for agent ${context.agentId}. '
      '(Full implementation pending)',
    );
  }
}
