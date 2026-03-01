import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/modules/agent_network/components/home_logo_section.dart';
import 'package:vide_cli/modules/agent_network/components/daemon_indicator.dart';
import 'package:vide_cli/modules/agent_network/components/network_list_section.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/commands/command_provider.dart';
import 'package:vide_cli/modules/commands/command.dart';
import 'package:vide_cli/modules/agent_network/state/prompt_history_provider.dart';
import 'package:vide_cli/modules/git/git_popup.dart';
import 'package:vide_cli/modules/settings/settings_dialog.dart';
import 'package:vide_cli/modules/remote/daemon_connection_service.dart';
import 'package:vide_cli/modules/remote/daemon_sessions_dialog.dart';

enum _HomeSection { input, daemonIndicator, networksList }

class HomePage extends StatefulComponent {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _commandResult;
  bool _commandResultIsError = false;
  bool _startupSessionConnectAttempted = false;

  _HomeSection _focusSection = _HomeSection.input;

  /// Cached file list from git ls-files for @mention suggestions.
  List<String>? _cachedFileList;
  DateTime? _cachedFileListTimestamp;

  void _tryAutoConnectConfiguredSession() {
    if (_startupSessionConnectAttempted) return;

    final remoteConfig = context.read(remoteConfigProvider);
    final sessionId = remoteConfig?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final daemonState = context.read(daemonConnectionProvider);
    if (!daemonState.isConnected) return;

    _startupSessionConnectAttempted = true;

    Future.microtask(() async {
      try {
        final sessionManager = context.read(videSessionManagerProvider);
        final session = await sessionManager.resumeSession(sessionId);
        if (!mounted) return;
        await NetworkExecutionPage.push(context, session: session);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _commandResult = 'Failed to connect to session $sessionId: $e';
          _commandResultIsError = true;
        });
      }
    });
  }

  Future<void> _handleSubmit(AgentMessage message) async {
    try {
      final worktreePath = context.read(repoPathOverrideProvider);
      final sessionManager = context.read(videSessionManagerProvider);

      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      final team = settings.extremeTeamEnabled ? 'extreme' : 'enterprise';

      final session = await sessionManager.createSession(
        initialMessage: message.text,
        workingDirectory: worktreePath ?? Directory.current.path,
        team: team,
        attachments: message.attachments,
      );

      await NetworkExecutionPage.push(context, session: session);
    } catch (e) {
      setState(() {
        _commandResult = 'Failed to create session: $e';
        _commandResultIsError = true;
      });

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _commandResult = null;
          });
        }
      });
    }
  }

  Future<void> _handleCommand(String commandInput) async {
    final dispatcher = context.read(commandDispatcherProvider);

    final commandContext = CommandContext(
      agentId: '',
      workingDirectory: Directory.current.path,
      sendMessage: null,
      clearConversation: null,
      exitApp: () async => shutdownApp(),
      detachApp: shutdownApp,
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

  Future<List<CommandSuggestion>> _getFileSuggestions(String query) async {
    final workingDir = context.read(currentRepoPathProvider);

    final now = DateTime.now();
    if (_cachedFileList == null ||
        _cachedFileListTimestamp == null ||
        now.difference(_cachedFileListTimestamp!) >
            const Duration(seconds: 10)) {
      try {
        final result = await Process.run(
          'git',
          ['ls-files', '--cached', '--others', '--exclude-standard'],
          workingDirectory: workingDir,
        );
        if (result.exitCode == 0) {
          _cachedFileList = (result.stdout as String)
              .split('\n')
              .where((l) => l.isNotEmpty)
              .toList();
          _cachedFileListTimestamp = now;
        }
      } catch (_) {
        return [];
      }
    }

    if (_cachedFileList == null) return [];

    // Empty query: show first N files. Non-empty: filter by substring match.
    final results = query.isEmpty
        ? _cachedFileList!.take(10)
        : _cachedFileList!
            .where((f) => f.toLowerCase().contains(query.toLowerCase()))
            .take(10);

    return results
        .map((f) => CommandSuggestion(name: f, description: 'file'))
        .toList();
  }

  // Height of the main content section (logo + path + input + result)
  // This is approximate: logo ~6 + spacing 1 + path 1 + spacing 1 + input 3 + padding 4 = ~16
  static const double _mainContentHeight = 16;

  @override
  Component build(BuildContext context) {
    _tryAutoConnectConfiguredSession();

    final theme = VideTheme.of(context);
    final currentDir = context.watch(currentRepoPathProvider);
    final daemonState = context.watch(daemonConnectionProvider);
    final networks = daemonState.isConnected
        ? context.watch(agentNetworksStateNotifierProvider).sessions
        : <VideSessionInfo>[];

    final textFieldFocused =
        _focusSection == _HomeSection.input ||
        _focusSection == _HomeSection.daemonIndicator;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.tab) {
          SettingsPopup.show(context);
          return true;
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          final networksHeight = networks.isNotEmpty && !textFieldFocused
              ? (totalHeight * 0.4).clamp(8.0, 20.0)
              : 0.0;
          final hintHeight = networks.isNotEmpty && textFieldFocused
              ? 4.0
              : 0.0;
          final availableForMain = totalHeight - networksHeight - hintHeight;
          final topPadding = ((availableForMain - _mainContentHeight) / 2)
              .clamp(0.0, double.infinity);

          return Stack(
            children: [
              Column(
                children: [
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
                          HomeLogoSection(repoPath: currentDir),
                          DaemonIndicator(
                            focused:
                                _focusSection == _HomeSection.daemonIndicator,
                            onDownEdge: () {
                              setState(
                                () => _focusSection = _HomeSection.input,
                              );
                            },
                            onEnter: () {
                              DaemonSessionsDialog.show(context);
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
                                      _focusSection == _HomeSection.input,
                                  placeholder:
                                      'Describe your goal (you can attach images)',
                                  onSubmit: _handleSubmit,
                                  onCommand: _handleCommand,
                                  commandSuggestions: _getCommandSuggestions,
                                  fileSuggestions: _getFileSuggestions,
                                  promptHistory: promptHistory,
                                  onPromptSubmitted: (prompt) => context
                                      .read(promptHistoryProvider.notifier)
                                      .addPrompt(prompt),
                                  onDownEdge: networks.isNotEmpty
                                      ? () => setState(() {
                                          _focusSection =
                                              _HomeSection.networksList;
                                        })
                                      : null,
                                  onUpEdge: () => setState(() {
                                    _focusSection =
                                        _HomeSection.daemonIndicator;
                                  }),
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

                  // Previous conversations section
                  if (networks.isNotEmpty)
                    NetworkListSection(
                      sessions: networks,
                      focused: _focusSection == _HomeSection.networksList,
                      listHeight: networksHeight,
                      onSessionSelected: (sessionId) {
                        final sessionManager = context.read(
                          videSessionManagerProvider,
                        );
                        sessionManager.resumeSession(sessionId).then((session) {
                          NetworkExecutionPage.push(context, session: session);
                        });
                      },
                      onSessionDeleted: (index) {
                        context
                            .read(agentNetworksStateNotifierProvider.notifier)
                            .deleteSession(index);
                      },
                      onUpEdge: () {
                        setState(() => _focusSection = _HomeSection.input);
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
