import '../command.dart';

/// Exits the Vide application.
class ExitCommand extends Command {
  @override
  String get name => 'exit';

  @override
  String get description => 'Exit the application';

  @override
  String get usage => '/exit';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.exitApp == null) {
      return CommandResult.error('Cannot exit: exit callback not available');
    }

    // Call the exit callback - this will trigger app shutdown
    context.exitApp!();

    // This message may not be shown since the app is exiting
    return CommandResult.success('Exiting...');
  }
}
