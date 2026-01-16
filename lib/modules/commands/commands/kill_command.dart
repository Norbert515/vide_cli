import '../command.dart';

/// Kills/terminates the current agent from the network.
///
/// Cannot be used if this is the last agent in the network.
class KillCommand extends Command {
  @override
  String get name => 'kill';

  @override
  String get description => 'Terminate this agent (cannot kill the last agent)';

  @override
  String get usage => '/kill';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.isLastAgent) {
      return CommandResult.error('Cannot kill the last agent');
    }

    if (context.killAgent == null) {
      return CommandResult.error('Kill not available');
    }

    try {
      await context.killAgent!();
      return CommandResult.success('Agent terminated');
    } catch (e) {
      return CommandResult.error('Failed to kill agent: $e');
    }
  }
}
