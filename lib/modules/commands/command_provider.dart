import 'package:riverpod/riverpod.dart';

import 'command_registry.dart';
import 'command_dispatcher.dart';
import 'commands/compact_command.dart';
import 'commands/clear_command.dart';
import 'commands/exit_command.dart';
import 'commands/ide_command.dart';

/// Provider for the command registry with all built-in commands registered.
final commandRegistryProvider = Provider<CommandRegistry>((ref) {
  final registry = CommandRegistry();

  // Register built-in commands
  registry.registerAll([
    ClearCommand(),
    CompactCommand(),
    ExitCommand(),
    IdeCommand(),
  ]);

  return registry;
});

/// Provider for the command dispatcher.
final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  return CommandDispatcher(ref.watch(commandRegistryProvider));
});
