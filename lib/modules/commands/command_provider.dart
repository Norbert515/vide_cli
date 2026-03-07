import 'package:riverpod/riverpod.dart';

import 'command_registry.dart';
import 'command_dispatcher.dart';
import 'commands/compact_command.dart';
import 'commands/clear_command.dart';
import 'commands/detach_command.dart';
import 'commands/exit_command.dart';
import 'commands/fork_command.dart';
import 'commands/git_command.dart';
import 'commands/kill_command.dart';
import 'commands/effort_command.dart';
import 'commands/logs_command.dart';
import 'commands/mcp_command.dart';
import 'commands/model_command.dart';
import 'commands/settings_command.dart';

/// Provider for the command registry with all built-in commands registered.
final commandRegistryProvider = Provider<CommandRegistry>((ref) {
  final registry = CommandRegistry();

  // Register built-in commands
  registry.registerAll([
    ClearCommand(),
    CompactCommand(),
    DetachCommand(),
    EffortCommand(),
    ExitCommand(),
    ForkCommand(),
    GitCommand(),
    KillCommand(),
    LogsCommand(),
    McpCommand(),
    ModelCommand(),
    SettingsCommand(),
  ]);

  return registry;
});

/// Provider for the command dispatcher.
final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  return CommandDispatcher(ref.watch(commandRegistryProvider));
});
