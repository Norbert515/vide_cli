import 'command.dart';

/// Registry for slash commands.
///
/// Commands are registered at startup and looked up by name when users
/// type `/commandName` in the chat input.
class CommandRegistry {
  final Map<String, Command> _commands = {};

  /// Register a command.
  ///
  /// Throws if a command with the same name is already registered.
  void register(Command command) {
    final name = command.name.toLowerCase();
    if (_commands.containsKey(name)) {
      throw ArgumentError('Command "$name" is already registered');
    }
    _commands[name] = command;
  }

  /// Register multiple commands at once.
  void registerAll(Iterable<Command> commands) {
    for (final command in commands) {
      register(command);
    }
  }

  /// Get a command by name (case-insensitive).
  ///
  /// Returns null if the command is not found.
  Command? getCommand(String name) {
    return _commands[name.toLowerCase()];
  }

  /// Check if a command exists.
  bool hasCommand(String name) {
    return _commands.containsKey(name.toLowerCase());
  }

  /// Get all registered commands.
  List<Command> get allCommands => _commands.values.toList();

  /// Get all command names.
  List<String> get commandNames => _commands.keys.toList();
}
