import '../command.dart';

class GitCommand extends Command {
  @override
  String get name => 'git';

  @override
  String get description => 'Show git operations popup';

  @override
  String get usage => '/git';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    await context.showGitPopup?.call();
    return CommandResult.success();
  }
}
