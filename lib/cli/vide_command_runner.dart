import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:vide_cli/cli/connect_command.dart';
import 'package:vide_cli/cli/daemon_command.dart';
import 'package:vide_cli/cli/session_server_command.dart';
import 'package:vide_cli/main.dart' as app;
import 'package:vide_core/vide_core.dart';

class VideCommandRunner extends CommandRunner<void> {
  VideCommandRunner()
    : super(
        'vide',
        'An agentic terminal UI for Claude, built for Flutter developers',
      ) {
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print version information',
      )
      ..addFlag(
        'dangerously-skip-permissions',
        negatable: false,
        help:
            'Skip all permission checks (DANGEROUS: only for sandboxed environments)',
      )
      ..addFlag(
        'local',
        negatable: false,
        help: 'Force local session mode (ignore daemon setting)',
      )
      ..addFlag('daemon', negatable: false, help: 'Force daemon session mode');

    addCommand(DaemonCommand());
    addCommand(ConnectCommand());
    addCommand(SessionServerCommand());
  }

  @override
  String? get usageFooter => '''

EXAMPLES:
    vide                                   Launch interactive TUI
    vide daemon start                      Start daemon on port 8080
    vide daemon start --port 9000          Start daemon on port 9000
    vide daemon start --detach             Start daemon in background
    vide daemon start --host 100.x.x.x    Bind to specific IP (e.g., Tailscale)
    vide daemon stop                       Stop the running daemon
    vide daemon status                     Show daemon status
    vide daemon install --port 9000        Install as system service
    vide daemon uninstall                  Remove system service
    vide connect 8080                      Connect to localhost:8080
    vide connect 192.168.1.10:8080         Connect to remote daemon
    vide connect 8080 --session abc123     Connect to specific session

ENVIRONMENT VARIABLES:
    DISABLE_AUTOUPDATER=1    Disable automatic updates
    DO_NOT_TRACK=1           Opt out of anonymous telemetry

SAFETY:
    Use --dangerously-skip-permissions ONLY in sandboxed environments
    (Docker, VMs) where filesystem isolation protects the host system.''';

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] as bool) {
      print('vide $videVersion');
      return;
    }

    if (topLevelResults.command != null) {
      await super.runCommand(topLevelResults);
      return;
    }

    // No subcommand: show help if requested
    if (topLevelResults['help'] as bool) {
      printUsage();
      return;
    }

    // No subcommand: launch the TUI
    final forceLocal = topLevelResults['local'] as bool;
    final forceDaemon = topLevelResults['daemon'] as bool;
    final dangerouslySkipPermissions =
        topLevelResults['dangerously-skip-permissions'] as bool;

    if (forceLocal && forceDaemon) {
      usageException('--local and --daemon cannot be used together');
    }

    final configManager = VideConfigManager();
    final overrides = [
      videConfigManagerProvider.overrideWithValue(configManager),
      workingDirProvider.overrideWithValue(Directory.current.path),
    ];

    await app.main(
      topLevelResults.rest,
      overrides: overrides,
      forceLocal: forceLocal,
      forceDaemon: forceDaemon,
      dangerouslySkipPermissions: dangerouslySkipPermissions,
    );
  }
}
