import '../command.dart';

/// Forks the current agent, creating a new agent with the same conversation context.
///
/// Uses Claude Code's native --fork-session capability to branch the conversation.
/// The new agent will start with the full conversation history from the source.
class ForkCommand extends Command {
  @override
  String get name => 'fork';

  @override
  String get description => 'Fork this agent into a new agent with the same context';

  @override
  String get usage => '/fork';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.forkAgent == null) {
      return CommandResult.error('Forking not available');
    }

    try {
      // No name argument - name is auto-generated as "[Fork] OriginalName"
      final newAgentId = await context.forkAgent!(null);
      return CommandResult.success('Forked: $newAgentId');
    } catch (e) {
      return CommandResult.error('Failed to fork: $e');
    }
  }
}
