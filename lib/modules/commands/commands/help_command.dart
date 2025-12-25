import '../command.dart';
import '../command_registry.dart';

/// Shows available commands and their descriptions.
class HelpCommand extends Command {
  HelpCommand(this._registry);

  final CommandRegistry _registry;

  @override
  String get name => 'help';

  @override
  String get description => 'Show available commands';

  @override
  String get usage => '/help';

  @override
  Future<CommandResult> execute(CommandContext context, String? arguments) async {
    final commands = _registry.allCommands;
    final buffer = StringBuffer();

    buffer.writeln('Available commands:');
    buffer.writeln();

    for (final command in commands) {
      buffer.writeln('  ${command.usage}');
      buffer.writeln('    ${command.description}');
      buffer.writeln();
    }

    return CommandResult.success(buffer.toString().trim());
  }
}
