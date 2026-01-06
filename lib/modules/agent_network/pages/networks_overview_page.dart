import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_list_page.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/components/attachment_text_field.dart';
import 'package:vide_cli/components/git_branch_indicator.dart';
import 'package:vide_cli/components/shimmer.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_cli/modules/commands/command.dart';

class NetworksOverviewPage extends StatefulComponent {
  const NetworksOverviewPage({super.key});

  @override
  State<NetworksOverviewPage> createState() => _NetworksOverviewPageState();
}

class _NetworksOverviewPageState extends State<NetworksOverviewPage> {
  ProjectType? projectType;
  String? _commandResult;
  bool _commandResultIsError = false;

  @override
  void initState() {
    super.initState();
    _loadProjectInfo();
  }

  Future<void> _loadProjectInfo() async {
    final currentDir = Directory.current.path;
    final detectedType = ProjectDetector.detectProjectType(currentDir);

    if (mounted) {
      setState(() {
        projectType = detectedType;
      });
    }
  }

  /// Abbreviates the path by replacing home directory with ~
  String _abbreviatePath(String fullPath) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && fullPath.startsWith(home)) {
      return '~${fullPath.substring(home.length)}';
    }
    return fullPath;
  }

  void _handleSubmit(Message message) async {
    // Start a new agent network with the full message (preserves attachments)
    // This returns immediately - client creation happens in background
    final network = await context
        .read(agentNetworkManagerProvider.notifier)
        .startNew(message);

    // Update the networks list
    context
        .read(agentNetworksStateNotifierProvider.notifier)
        .upsertNetwork(network);

    // Navigate to the execution page immediately
    await NetworkExecutionPage.push(context, network.id);
  }

  Future<void> _handleCommand(String commandInput) async {
    final dispatcher = context.read(commandDispatcherProvider);

    final commandContext = CommandContext(
      agentId: '',
      workingDirectory: Directory.current.path,
      sendMessage: null,
      clearConversation: null,
      exitApp: shutdownApp,
      toggleIdeMode: () {
        final container = ProviderScope.containerOf(context);
        final current = container.read(ideModeEnabledProvider);
        container.read(ideModeEnabledProvider.notifier).state = !current;

        final configManager = container.read(videConfigManagerProvider);
        final settings = configManager.readGlobalSettings();
        configManager.writeGlobalSettings(
          settings.copyWith(ideModeEnabled: !current),
        );
      },
    );

    final result = await dispatcher.dispatch(commandInput, commandContext);

    setState(() {
      _commandResult = result.success ? result.message : result.error;
      _commandResultIsError = !result.success;
    });

    // Auto-clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _commandResult = null;
        });
      }
    });
  }

  List<CommandSuggestion> _getCommandSuggestions(String prefix) {
    final registry = context.read(commandRegistryProvider);
    final allCommands = registry.allCommands;

    final matching = allCommands.where((cmd) {
      return cmd.name.toLowerCase().startsWith(prefix.toLowerCase());
    }).toList();

    return matching.map((cmd) {
      return CommandSuggestion(name: cmd.name, description: cmd.description);
    }).toList();
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Get current directory path (abbreviated)
    final currentDir = Directory.current.path;
    final abbreviatedPath = _abbreviatePath(currentDir);

    // Check if IDE mode is enabled
    final configManager = context.read(videConfigManagerProvider);
    final ideModeEnabled = configManager.readGlobalSettings().ideModeEnabled;

    // Watch sidebar focus state from app-level provider
    final sidebarFocused = context.watch(sidebarFocusProvider);

    return Focusable(
      focused: !sidebarFocused,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.tab) {
          NetworksListPage.push(context);
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          padding: EdgeInsets.all(2),
          constraints: BoxConstraints(maxWidth: 120, maxHeight: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ASCII Logo with shimmer effect
              Shimmer(
                delay: Duration(seconds: 4),
                duration: Duration(milliseconds: 1000),
                angle: 0.7,
                highlightWidth: 6,
                child: AsciiText(
                  'VIDE',
                  font: AsciiFont.standard,
                  style: TextStyle(color: theme.base.primary),
                ),
              ),
              const SizedBox(height: 1),
              // Running in path with git branch (both as badges)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Running in ',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                  Text(
                    ' $abbreviatedPath ',
                    style: TextStyle(
                      color: theme.base.background,
                      backgroundColor: theme.base.primary,
                    ),
                  ),
                  Text(
                    ' on ',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                  GitBranchIndicator(repoPath: currentDir),
                ],
              ),
              const SizedBox(height: 1),
              Container(
                child: AttachmentTextField(
                  focused: !sidebarFocused,
                  placeholder: 'Describe your goal (you can attach images)',
                  onSubmit: _handleSubmit,
                  onCommand: _handleCommand,
                  commandSuggestions: _getCommandSuggestions,
                  onLeftEdge: ideModeEnabled
                      ? () =>
                            context.read(sidebarFocusProvider.notifier).state =
                                true
                      : null,
                ),
                padding: EdgeInsets.all(1),
              ),
              // Command result feedback
              if (_commandResult != null)
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Text(
                    _commandResult!,
                    style: TextStyle(
                      color: _commandResultIsError
                          ? theme.base.error
                          : theme.base.onSurface.withOpacity(
                              TextOpacity.secondary,
                            ),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Tab: past networks & settings | Enter: start',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
