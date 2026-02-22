import '../command.dart';

class LogsCommand extends Command {
  @override
  String get name => 'logs';

  @override
  String get description => 'Open the current session log file';

  @override
  String get usage => '/logs';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    context.showSessionLogs?.call();
    return CommandResult.success();
  }
}
