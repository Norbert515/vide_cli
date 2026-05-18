import '../command.dart';

/// Detaches from the session, exiting the TUI but leaving the daemon session running.
class DetachCommand extends Command {
  @override
  String get name => 'detach';

  @override
  String get description => 'Close the TUI (daemon session keeps running)';

  @override
  String get usage => '/detach';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.detachApp == null) {
      return CommandResult.error(
        'Cannot detach: not available in this context',
      );
    }

    context.detachApp!();

    return CommandResult.success('Detaching...');
  }
}
