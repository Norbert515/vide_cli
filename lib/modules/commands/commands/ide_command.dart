import '../command.dart';

class IdeCommand extends Command {
  @override
  String get name => 'ide';

  @override
  String get description => 'Toggle IDE mode (show/hide git sidebar)';

  @override
  String get usage => '/ide';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    context.toggleIdeMode?.call();
    return CommandResult.success('IDE mode toggled');
  }
}
