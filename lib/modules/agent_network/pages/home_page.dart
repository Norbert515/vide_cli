import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/components/network_summary_component.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/modules/git/git_branch_indicator.dart';
import 'package:vide_cli/components/shimmer.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_cli/modules/commands/command.dart';
import 'package:vide_cli/modules/agent_network/state/prompt_history_provider.dart';
import 'package:vide_cli/modules/git/git_popup.dart';
import 'package:vide_cli/modules/settings/settings_dialog.dart';

class HomePage extends StatefulComponent {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ProjectType? projectType;
  String? _commandResult;
  bool _commandResultIsError = false;

  // Focus state: 'textField', 'teamSelector', or 'networksList'
  String _focusState = 'textField';

  // Team selector state
  List<String> _availableTeams = [];
  int _selectedTeamIndex = 0;

  // Networks list state
  int _selectedNetworkIndex = 0;
  int? _pendingDeleteIndex;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProjectInfo();
    _initializeClaude();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final workingDir = Directory.current.path;
    final loader = TeamFrameworkLoader(workingDirectory: workingDir);
    final teams = await loader.loadTeams();

    final teamList = teams.keys.toList()..sort();
    final currentTeam = context.read(currentTeamProvider);

    // Find the current team's index
    var initialIndex = teamList.indexOf(currentTeam);
    if (initialIndex < 0) initialIndex = 0;

    if (mounted) {
      setState(() {
        _availableTeams = teamList;
        _selectedTeamIndex = initialIndex;
      });
    }
  }

  /// Initialize Claude client at startup so it's ready when user submits.
  void _initializeClaude() {
    // Pre-warm by accessing initial client via VideCore
    final _ = context.read(videoCoreProvider).initialClient;
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
    // Use the repo path override if user selected a worktree before starting
    final worktreePath = context.read(repoPathOverrideProvider);
    final currentTeam = context.read(currentTeamProvider);
    final network = await context
        .read(agentNetworkManagerProvider.notifier)
        .startNew(message, workingDirectory: worktreePath, team: currentTeam);

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
      showGitPopup: () async {
        final repoPath = context.read(currentRepoPathProvider);
        await GitPopup.show(context, repoPath: repoPath);
      },
      showSettingsDialog: () async {
        await SettingsPopup.show(context);
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

  /// Handle key events when the team selector is focused.
  /// Returns true if the event was handled.
  bool _handleTeamSelectorKeyEvent(KeyboardEvent event) {
    if (_availableTeams.isEmpty) return false;

    if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.keyH) {
      setState(() {
        _selectedTeamIndex--;
        if (_selectedTeamIndex < 0)
          _selectedTeamIndex = _availableTeams.length - 1;
      });
      return true;
    } else if (event.logicalKey == LogicalKey.arrowRight ||
        event.logicalKey == LogicalKey.keyL) {
      setState(() {
        _selectedTeamIndex++;
        if (_selectedTeamIndex >= _availableTeams.length)
          _selectedTeamIndex = 0;
      });
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.escape) {
      // Select current team and go back to text field
      if (_selectedTeamIndex < _availableTeams.length) {
        context.read(currentTeamProvider.notifier).state =
            _availableTeams[_selectedTeamIndex];
      }
      setState(() => _focusState = 'textField');
      return true;
    }
    return false;
  }

  /// Handle key events when the networks list is focused.
  /// Returns true if the event was handled.
  bool _handleNetworkListKeyEvent(
    KeyboardEvent event,
    List<AgentNetwork> networks,
  ) {
    if (networks.isEmpty) return false;

    if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        _selectedNetworkIndex++;
        _selectedNetworkIndex = _selectedNetworkIndex.clamp(
          0,
          networks.length - 1,
        );
        _pendingDeleteIndex = null;
      });
      // Ensure visible after render - account for spacers: network i is at child index i*2
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollController.ensureIndexVisible(index: _selectedNetworkIndex * 2);
      });
      return true;
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      // If at the top of the list, move focus back to text field
      if (_selectedNetworkIndex == 0) {
        setState(() {
          _focusState = 'textField';
          _pendingDeleteIndex = null;
        });
        return true;
      }
      setState(() {
        _selectedNetworkIndex--;
        _selectedNetworkIndex = _selectedNetworkIndex.clamp(
          0,
          networks.length - 1,
        );
        _pendingDeleteIndex = null;
      });
      // Ensure visible after render - account for spacers: network i is at child index i*2
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollController.ensureIndexVisible(index: _selectedNetworkIndex * 2);
      });
      return true;
    } else if (event.logicalKey == LogicalKey.backspace) {
      if (_pendingDeleteIndex == _selectedNetworkIndex) {
        // Second press - actually delete the network
        context
            .read(agentNetworksStateNotifierProvider.notifier)
            .deleteNetwork(_selectedNetworkIndex);
        setState(() {
          _pendingDeleteIndex = null;
          if (_selectedNetworkIndex >= networks.length - 1) {
            _selectedNetworkIndex = (networks.length - 2).clamp(
              0,
              networks.length - 1,
            );
          }
        });
      } else {
        // First press - set pending delete
        setState(() {
          _pendingDeleteIndex = _selectedNetworkIndex;
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.enter) {
      final network = networks[_selectedNetworkIndex];
      // Update the team provider to match the network's team
      context.read(currentTeamProvider.notifier).state = network.team;
      // Await resume to complete before navigating to prevent flash of empty state
      context.read(videoCoreProvider).resumeSession(network.id).then((_) {
        NetworkExecutionPage.push(context, network.id);
      });
      return true;
    }
    return false;
  }

  // Height of the main content section (logo + path + team hint + input + result)
  // This is approximate: logo ~6 + spacing 1 + path 1 + spacing 1 + team hint 1 + spacing 1 + input 3 + padding 4 = ~18
  static const double _mainContentHeight = 18;

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Get current directory path (abbreviated) - use currentRepoPathProvider to
    // react to worktree switching
    final currentDir = context.watch(currentRepoPathProvider);
    final abbreviatedPath = _abbreviatePath(currentDir);

    // Watch sidebar focus state from app-level provider
    final sidebarFocused = context.watch(sidebarFocusProvider);

    // Get networks list
    final networks = context.watch(agentNetworksStateNotifierProvider).networks;

    // Clamp selection if list length changed
    if (networks.isNotEmpty && _selectedNetworkIndex >= networks.length) {
      _selectedNetworkIndex = (networks.length - 1).clamp(
        0,
        networks.length - 1,
      );
    }

    return Focusable(
      focused: !sidebarFocused,
      onKeyEvent: (event) {
        // Tab: Quick access to settings (when not consumed by text field autocomplete)
        if (event.logicalKey == LogicalKey.tab) {
          SettingsPopup.show(context);
          return true;
        }

        // Handle events based on current focus state
        if (_focusState == 'teamSelector') {
          return _handleTeamSelectorKeyEvent(event);
        } else if (_focusState == 'networksList' && networks.isNotEmpty) {
          return _handleNetworkListKeyEvent(event, networks);
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          // Calculate top padding to center the main content vertically
          // When text field is focused: only reserve space for the hint line (~3 lines)
          // When networks list is focused: reserve full space for the list
          final textFieldFocused =
              _focusState == 'textField' || _focusState == 'teamSelector';
          final networksHeight = networks.isNotEmpty && !textFieldFocused
              ? (totalHeight * 0.4).clamp(8.0, 20.0)
              : 0.0;
          // Reserve a small amount for the hint when text field is focused
          final hintHeight = networks.isNotEmpty && textFieldFocused
              ? 4.0
              : 0.0;
          final availableForMain = totalHeight - networksHeight - hintHeight;
          final topPadding = ((availableForMain - _mainContentHeight) / 2)
              .clamp(0.0, double.infinity);

          return Column(
            children: [
              // Top spacer for vertical centering
              SizedBox(height: topPadding),

              // Main content section (logo, path, input)
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  constraints: BoxConstraints(maxWidth: 120),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      // Team selector (inline with all teams visible)
                      Builder(
                        builder: (context) {
                          final currentTeam = context.watch(
                            currentTeamProvider,
                          );
                          final teamSelectorFocused =
                              _focusState == 'teamSelector';

                          if (_availableTeams.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          // Show all teams inline, highlight the selected/current one
                          final displayIndex = teamSelectorFocused
                              ? _selectedTeamIndex
                              : _availableTeams
                                    .indexOf(currentTeam)
                                    .clamp(0, _availableTeams.length - 1);

                          return Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Show arrow hint when focused
                                if (teamSelectorFocused)
                                  Text(
                                    '← ',
                                    style: TextStyle(color: theme.base.primary),
                                  )
                                else
                                  Text(
                                    '↑ ',
                                    style: TextStyle(
                                      color: theme.base.onSurface.withOpacity(
                                        TextOpacity.tertiary,
                                      ),
                                    ),
                                  ),
                                // Show all teams
                                for (
                                  int i = 0;
                                  i < _availableTeams.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: theme.base.onSurface.withOpacity(
                                          TextOpacity.tertiary,
                                        ),
                                      ),
                                    ),
                                  if (i == displayIndex)
                                    Text(
                                      ' ${_availableTeams[i]} ',
                                      style: TextStyle(
                                        color: theme.base.background,
                                        backgroundColor: theme.base.primary,
                                      ),
                                    )
                                  else
                                    Text(
                                      _availableTeams[i],
                                      style: TextStyle(
                                        color: theme.base.onSurface.withOpacity(
                                          teamSelectorFocused
                                              ? TextOpacity.secondary
                                              : TextOpacity.tertiary,
                                        ),
                                      ),
                                    ),
                                ],
                                // Show arrow hint when focused
                                if (teamSelectorFocused)
                                  Text(
                                    ' →',
                                    style: TextStyle(color: theme.base.primary),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 1),
                      Container(
                        padding: EdgeInsets.all(1),
                        child: Builder(
                          builder: (context) {
                            final promptHistory = context.watch(
                              promptHistoryProvider,
                            );
                            return AttachmentTextField(
                              focused:
                                  _focusState == 'textField' && !sidebarFocused,
                              placeholder:
                                  'Describe your goal (you can attach images)',
                              onSubmit: _handleSubmit,
                              onCommand: _handleCommand,
                              commandSuggestions: _getCommandSuggestions,
                              promptHistory: promptHistory,
                              onPromptSubmitted: (prompt) => context
                                  .read(promptHistoryProvider.notifier)
                                  .addPrompt(prompt),
                              // No sidebar on home page, so no onLeftEdge handler
                              onDownEdge: networks.isNotEmpty
                                  ? () => setState(() {
                                      _focusState = 'networksList';
                                      _selectedNetworkIndex = 0;
                                    })
                                  : null,
                              onUpEdge: _availableTeams.isNotEmpty
                                  ? () => setState(() {
                                      _focusState = 'teamSelector';
                                    })
                                  : null,
                            );
                          },
                        ),
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
                    ],
                  ),
                ),
              ),

              // Flexible space between main content and networks
              if (networks.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Enter: start a new conversation',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                  ),
                ),

              // Previous conversations section
              if (networks.isNotEmpty) ...[
                const SizedBox(height: 2),

                // Show hint when text field focused, full header when list focused
                if (textFieldFocused)
                  Center(
                    child: Text(
                      '↓ ${networks.length} previous conversation${networks.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                  )
                else
                  // Section header (when list is focused)
                  Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 120),
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Text(
                            '─── ',
                            style: TextStyle(
                              color: theme.base.outline.withOpacity(
                                TextOpacity.separator,
                              ),
                            ),
                          ),
                          Text(
                            'Previous Conversations',
                            style: TextStyle(
                              color: theme.base.onSurface.withOpacity(
                                TextOpacity.secondary,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (↑↓ ⏎ ⌫⌫) ',
                            style: TextStyle(
                              color: theme.base.onSurface.withOpacity(
                                TextOpacity.tertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '─────────────────────────────────────────',
                              style: TextStyle(
                                color: theme.base.outline.withOpacity(
                                  TextOpacity.separator,
                                ),
                              ),
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 1),

                // Networks list (only shown when list is focused)
                if (!textFieldFocused)
                  SizedBox(
                    height: networksHeight,
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 120),
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: ListView(
                          lazy: true,
                          controller: _scrollController,
                          children: [
                            for (int i = 0; i < networks.length; i++) ...[
                              NetworkSummaryComponent(
                                network: networks[i],
                                selected: _selectedNetworkIndex == i,
                                showDeleteConfirmation:
                                    _pendingDeleteIndex == i,
                              ),
                              if (i < networks.length - 1) SizedBox(height: 1),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
