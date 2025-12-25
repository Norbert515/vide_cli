import 'command.dart';
import 'command_registry.dart';

/// Parses and dispatches slash commands.
class CommandDispatcher {
  CommandDispatcher(this.registry);

  final CommandRegistry registry;

  /// Check if the input is a command (starts with /).
  bool isCommand(String input) {
    final trimmed = input.trim();
    return trimmed.startsWith('/') && trimmed.length > 1;
  }

  /// Parse a command string into name and arguments.
  ///
  /// Returns (commandName, arguments) where arguments may be null.
  /// The command name does not include the leading slash.
  ///
  /// Examples:
  ///   "/compact" -> ("compact", null)
  ///   "/compact focus on code" -> ("compact", "focus on code")
  ///   "/help" -> ("help", null)
  (String name, String? arguments) parseCommand(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('/')) {
      throw ArgumentError('Input must start with /');
    }

    // Remove leading slash
    final withoutSlash = trimmed.substring(1);

    // Split on first whitespace
    final spaceIndex = withoutSlash.indexOf(RegExp(r'\s'));
    if (spaceIndex == -1) {
      // No arguments
      return (withoutSlash.toLowerCase(), null);
    }

    final name = withoutSlash.substring(0, spaceIndex).toLowerCase();
    final arguments = withoutSlash.substring(spaceIndex + 1).trim();

    return (name, arguments.isEmpty ? null : arguments);
  }

  /// Dispatch a command string to the appropriate handler.
  ///
  /// Returns a [CommandResult] with the outcome.
  Future<CommandResult> dispatch(String input, CommandContext context) async {
    if (!isCommand(input)) {
      return CommandResult.error('Not a command: $input');
    }

    final (name, arguments) = parseCommand(input);
    final command = registry.getCommand(name);

    if (command == null) {
      final available = registry.commandNames.join(', ');
      return CommandResult.error(
        'Unknown command: /$name. Available commands: $available',
      );
    }

    return command.execute(context, arguments);
  }
}
