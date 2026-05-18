import '../command.dart';

class SettingsCommand extends Command {
  @override
  String get name => 'settings';

  @override
  String get description => 'Open settings dialog (team selection)';

  @override
  String get usage => '/settings';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    await context.showSettingsDialog?.call();
    return CommandResult.success();
  }
}
