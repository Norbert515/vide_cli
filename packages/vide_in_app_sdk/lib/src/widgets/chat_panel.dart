import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vide_client/vide_client.dart';
import 'package:vide_mobile/core/theme/tokens.dart';
import 'package:vide_mobile/core/theme/vide_colors.dart';
import 'package:vide_mobile/features/chat/widgets/chat_helpers.dart';
import 'package:vide_mobile/features/chat/widgets/tool_card.dart';
import 'package:vide_mobile/features/chat/widgets/typing_indicator.dart';

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:vide_mobile/features/chat/widgets/agent_tab_bar.dart';
import 'package:vide_mobile/features/chat/widgets/input_bar.dart';
import 'package:vide_mobile/features/permissions/ask_user_question_sheet.dart';
import 'package:vide_mobile/features/permissions/permission_sheet.dart';
import 'package:vide_mobile/features/permissions/plan_approval_sheet.dart';

import '../services/voice_input_service.dart';
import '../state/sdk_state.dart';

/// Chat panel for interacting with the Vide AI assistant.
///
/// Manages connection setup, message input (text + voice), streaming
/// responses, and permission handling.
class VideChatPanel extends StatefulWidget {
  final VideSdkState sdkState;
  final VoiceInputService voiceService;

  /// Called when the user wants to take a screenshot.
  final VoidCallback? onScreenshotRequest;

  /// Pending screenshot attachment (set after screenshot flow completes).
  final Uint8List? pendingScreenshot;

  /// Called to clear the pending screenshot.
  final VoidCallback? onClearScreenshot;

  const VideChatPanel({
    super.key,
    required this.sdkState,
    required this.voiceService,
    this.onScreenshotRequest,
    this.pendingScreenshot,
    this.onClearScreenshot,
  });

  @override
  State<VideChatPanel> createState() => _VideChatPanelState();
}

class _VideChatPanelState extends State<VideChatPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _workingDirController = TextEditingController();
  bool _voiceInitialized = false;
  bool _showingConfig = false;
  bool _testingConnection = false;
  _ConnectionTestResult? _testResult;
  bool _isPlanApprovalSheetShowing = false;
  bool _isAskUserQuestionSheetShowing = false;
  bool _isPermissionSheetShowing = false;

  // Agent tab state
  int _selectedTabIndex = 0;
  List<VideAgent> _agents = [];
  final Map<String, ScrollController> _agentScrollControllers = {};

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _workingDirController.dispose();
    for (final c in _agentScrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && widget.pendingScreenshot == null) return;

    List<VideAttachment>? attachments;
    if (widget.pendingScreenshot != null) {
      attachments = [
        VideAttachment(
          type: 'image',
          content: base64Encode(widget.pendingScreenshot!),
          mimeType: 'image/png',
        ),
      ];
      widget.onClearScreenshot?.call();
    }

    final state = widget.sdkState;
    if (!state.hasActiveSession) {
      state.createSession(text, attachments: attachments);
    } else {
      state.sendMessage(text, attachments: attachments);
    }

    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // reversed list: 0 is the bottom
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (!_voiceInitialized) {
      _voiceInitialized = await widget.voiceService.initialize();
      if (!_voiceInitialized) return;
    }

    if (widget.voiceService.isListening) {
      final text = await widget.voiceService.stopListening();
      if (text.isNotEmpty) {
        _textController.text = text;
      }
    } else {
      await widget.voiceService.startListening(
        onResult: (text) {
          _textController.text = text;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sdkState,
      builder: (context, _) {
        final hasSession = widget.sdkState.session != null;

        // Sync agent list and scroll controllers
        final currentAgents = widget.sdkState.session?.state.agents ?? [];
        if (currentAgents != _agents) {
          _agents = currentAgents;
          for (final agent in currentAgents) {
            _agentScrollControllers.putIfAbsent(
                agent.id, () => ScrollController());
          }
          final agentIds = currentAgents.map((a) => a.id).toSet();
          final removed = _agentScrollControllers.keys
              .where((id) => !agentIds.contains(id))
              .toList();
          for (final id in removed) {
            _agentScrollControllers[id]?.dispose();
            _agentScrollControllers.remove(id);
          }
          if (_selectedTabIndex >= _agents.length && _agents.isNotEmpty) {
            _selectedTabIndex = 0;
          }
        }

        final currentPermission = widget.sdkState.currentPermission;
        if (currentPermission != null && !_isPermissionSheetShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.sdkState.currentPermission != null) {
              _showPermissionSheet(widget.sdkState.currentPermission!);
            }
          });
        }

        final pendingPlan = widget.sdkState.pendingPlanApproval;
        if (pendingPlan != null && !_isPlanApprovalSheetShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.sdkState.pendingPlanApproval != null) {
              _showPlanApprovalSheet(widget.sdkState.pendingPlanApproval!);
            }
          });
        }

        final pendingQuestion = widget.sdkState.pendingAskUserQuestion;
        if (pendingQuestion != null && !_isAskUserQuestionSheetShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.sdkState.pendingAskUserQuestion != null) {
              _showAskUserQuestionSheet(
                  widget.sdkState.pendingAskUserQuestion!);
            }
          });
        }

        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: _showingConfig
              ? _buildConfigLayout(context)
              : hasSession
                  ? _buildSessionLayout(context)
                  : _buildEmptyLayout(context),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Permission sheet
  // ---------------------------------------------------------------------------

  void _showPermissionSheet(PermissionRequestEvent request) {
    if (_isPermissionSheetShowing) return;
    _isPermissionSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => PermissionSheet(
        request: request,
        onAllow: ({required bool remember}) {
          widget.sdkState.respondToPermission(
            request.requestId,
            allow: true,
            remember: remember,
          );
          Navigator.of(sheetContext).pop();
        },
        onDeny: () {
          widget.sdkState.respondToPermission(
            request.requestId,
            allow: false,
          );
          Navigator.of(sheetContext).pop();
        },
      ),
    ).whenComplete(() {
      _isPermissionSheetShowing = false;
      widget.sdkState.dequeuePermission();
    });
  }

  // ---------------------------------------------------------------------------
  // Plan approval sheet
  // ---------------------------------------------------------------------------

  void _showPlanApprovalSheet(PlanApprovalRequestEvent request) {
    if (_isPlanApprovalSheetShowing) return;
    _isPlanApprovalSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) => PlanApprovalSheet(
        request: request,
        onResponse: (action, feedback) {
          widget.sdkState.respondToPlanApproval(
            request.requestId,
            action: action,
            feedback: feedback,
          );
          widget.sdkState.clearPendingPlanApproval();
          _isPlanApprovalSheetShowing = false;
          Navigator.of(sheetContext).pop();
        },
      ),
    ).whenComplete(() {
      _isPlanApprovalSheetShowing = false;
    });
  }

  // ---------------------------------------------------------------------------
  // AskUserQuestion sheet
  // ---------------------------------------------------------------------------

  void _showAskUserQuestionSheet(AskUserQuestionEvent request) {
    if (_isAskUserQuestionSheetShowing) return;
    _isAskUserQuestionSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) => AskUserQuestionSheet(
        request: request,
        onSubmit: (answers) {
          widget.sdkState.respondToAskUserQuestion(
            request.requestId,
            answers: answers,
          );
          widget.sdkState.clearPendingAskUserQuestion();
          _isAskUserQuestionSheetShowing = false;
          Navigator.of(sheetContext).pop();
        },
      ),
    ).whenComplete(() {
      _isAskUserQuestionSheetShowing = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Empty layout — welcome screen with centered prompt
  // ---------------------------------------------------------------------------

  Widget _buildEmptyLayout(BuildContext context) {
    final sessions = widget.sdkState.sessions;
    final hasSessions = sessions.isNotEmpty;

    return Column(
      children: [
        // Error banner if needed
        if (widget.sdkState.connectionState == VideSdkConnectionState.error)
          _buildErrorBanner(context),

        // Content area
        Expanded(
          child: hasSessions
              ? _buildSessionListView(context, sessions)
              : _buildWelcomeView(context),
        ),

        // Bottom input + settings
        if (widget.pendingScreenshot != null)
          _buildScreenshotPreview(context),
        _buildBottomInput(context),
      ],
    );
  }

  /// Centered welcome view when there are no sessions.
  Widget _buildWelcomeView(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 48,
              color: videColors.accent.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'What can I help with?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe a task, ask a question, or\nattach a screenshot to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: videColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom input bar used on empty layout — works for both new and existing
  /// sessions.
  Widget _buildBottomInput(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.only(
                    left: 16, right: 4, top: 4, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Ask anything...',
                          hintStyle:
                              TextStyle(color: colorScheme.onSurfaceVariant),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: TextStyle(
                            color: colorScheme.onSurface, fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onScreenshotRequest,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.crop_rounded,
                          color: videColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: videColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: colorScheme.surface,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showingConfig = !_showingConfig),
              child: Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: videColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Session list with swipe-to-delete.
  Widget _buildSessionListView(
    BuildContext context,
    List<SessionSummary> sessions,
  ) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
          child: Text(
            'RECENT SESSIONS',
            style: TextStyle(
              color: videColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final session in sessions)
          Dismissible(
            key: ValueKey(session.sessionId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: videColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline,
                  color: videColors.error, size: 20),
            ),
            confirmDismiss: (_) async {
              return _confirmStopSession(context, session);
            },
            onDismissed: (_) {},
            child: _SessionTile(
              session: session,
              onTap: () =>
                  widget.sdkState.connectToSession(session.sessionId),
              videColors: videColors,
              colorScheme: colorScheme,
            ),
          ),
      ],
    );
  }

  /// Confirm and stop a session. Returns true if dismissed.
  Future<bool> _confirmStopSession(
    BuildContext context,
    SessionSummary session,
  ) async {
    final client = widget.sdkState.client;
    if (client == null) return false;

    try {
      await client.stopSession(session.sessionId);
      if (mounted) {
        await widget.sdkState.fetchSessions();
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop session: $e')),
        );
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session layout — header + messages + input
  // ---------------------------------------------------------------------------

  Widget _buildSessionLayout(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),

        if (widget.sdkState.connectionState == VideSdkConnectionState.error)
          _buildErrorBanner(context),

        Expanded(child: _buildChatContent(context)),

        if (widget.pendingScreenshot != null)
          _buildScreenshotPreview(context),
        _buildInputBar(context),
      ],
    );
  }

  /// The chat content (agent tabs + message list) — extracted from the old
  /// _buildSessionLayout so it can be one branch of the view switcher.
  Widget _buildChatContent(BuildContext context) {
    return Column(
      children: [
        if (_agents.length > 1)
          LiquidGlassLayer(
            settings: const LiquidGlassSettings(
              thickness: 2,
              refractiveIndex: 1.2,
              glassColor: Color(0x18FFFFFF),
              lightAngle: 0.5,
            ),
            child: AgentTabBar(
              agents: _agents,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
            ),
          ),
        Expanded(child: _buildTabContent(context)),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context) {
    final session = widget.sdkState.session;
    if (session == null || _agents.isEmpty) {
      return _buildMessageList(context);
    }

    final pending = session.pendingPermissionRequest;

    final tabViews = [
      for (final agent in _agents)
        _MessageList(
          agentState: session.conversationState.getAgentState(agent.id),
          agentId: agent.id,
          agentStatus: agent.status,
          agents: _agents,
          pendingPermission: pending,
          scrollController:
              _agentScrollControllers[agent.id] ?? ScrollController(),
          onAgentTap: (agentId) {
            final i = _agents.indexWhere((a) => a.id == agentId);
            if (i >= 0) setState(() => _selectedTabIndex = i);
          },
          onToolTap: _openToolDetail,
        ),
    ];

    return IndexedStack(
      index: _selectedTabIndex.clamp(0, tabViews.length - 1),
      children: tabViews,
    );
  }

  void _openToolDetail(ToolContent tool) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToolDetailScreen(tool: tool),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings layout
  // ---------------------------------------------------------------------------

  Widget _buildConfigLayout(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Column(
      children: [
        // Settings header with back button
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.sm,
            vertical: VideSpacing.xs,
          ),
          child: Row(
            children: [
              _InputBarButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => setState(() => _showingConfig = false),
                color: videColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                'Settings',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Config form fills the rest
        Expanded(child: _buildConfigForm(context)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Session header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final state = widget.sdkState;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.md,
        vertical: VideSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _headerTitle(state),
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _InputBarButton(
            icon: Icons.tune_rounded,
            onTap: () => setState(() => _showingConfig = !_showingConfig),
          ),
          const SizedBox(width: 4),
          _InputBarButton(
            icon: Icons.close_rounded,
            onTap: () => widget.sdkState.disconnect(),
            color: videColors.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }

  String _headerTitle(VideSdkState state) {
    final goal = state.videState?.goal;
    if (goal != null && goal != 'Session' && goal.isNotEmpty) return goal;
    return 'Vide Assistant';
  }

  // ---------------------------------------------------------------------------
  // Error banner
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final message = widget.sdkState.errorMessage ?? 'Connection failed';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: VideSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: videColors.errorContainer,
        borderRadius: VideRadius.smAll,
        border: Border.all(color: videColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: videColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: videColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => widget.sdkState.disconnect(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh, size: 16, color: videColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message list — flattened render items like vide_mobile
  // ---------------------------------------------------------------------------

  Widget _buildMessageList(BuildContext context) {
    final session = widget.sdkState.session;
    if (session == null) return const SizedBox.shrink();

    final mainAgent = session.state.mainAgent;
    if (mainAgent == null) return const SizedBox.shrink();

    final conversation = session.getConversation(mainAgent.id);
    if (conversation == null) return const SizedBox.shrink();

    final agents = session.state.agents;
    final pending = session.pendingPermissionRequest;

    // Flatten ConversationEntry content blocks into render items
    final items = <_RenderItem>[];
    for (final entry in conversation.messages) {
      for (final content in entry.content) {
        switch (content) {
          case TextContent():
            if (content.text.isNotEmpty) {
              items.add(_TextRenderItem(entry, content));
            }
          case ToolContent():
            if (!isHiddenTool(content)) {
              items.add(_ToolRenderItem(entry, content));
            }
          case AttachmentContent():
            break;
        }
      }
    }

    // Hide the last tool card if it's the one awaiting permission —
    // the permission banner already shows all the tool info.
    if (pending != null &&
        pending.agentId == mainAgent.id &&
        items.isNotEmpty) {
      final last = items.last;
      if (last is _ToolRenderItem &&
          last.tool.isExecuting &&
          last.tool.toolName == pending.toolName) {
        items.removeLast();
      }
    }

    // Use per-agent status for typing indicator, not global isProcessing
    final agentStatus = mainAgent.status;
    final isAgentBusy = agentStatus == VideAgentStatus.working ||
        agentStatus == VideAgentStatus.waitingForAgent;
    final showTyping = isAgentBusy;
    final totalCount = items.length + (showTyping ? 1 : 0);

    if (items.isEmpty && !showTyping) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: VideSpacing.sm),
      itemCount: totalCount,
      itemBuilder: (context, reverseIndex) {
        // In a reversed list, index 0 is the bottom (newest).
        if (showTyping && reverseIndex == 0) {
          return const TypingIndicator();
        }
        final itemIndex = items.length -
            1 -
            (showTyping ? reverseIndex - 1 : reverseIndex);
        final item = items[itemIndex];
        switch (item) {
          case _TextRenderItem(:final entry, :final content):
            return _MessageBubble(entry: entry, content: content);
          case _ToolRenderItem(:final tool):
            if (isSpawnAgentTool(tool)) {
              return SpawnAgentCard(tool: tool, agents: agents);
            }
            if (tool.toolName == 'ExitPlanMode') {
              return PlanResultIndicator(tool: tool);
            }
            return ToolCard(tool: tool);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Config form
  // ---------------------------------------------------------------------------

  Widget _buildConfigForm(BuildContext context) {
    final state = widget.sdkState;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    // Initialize controllers from existing state
    if (_hostController.text.isEmpty && state.host != null) {
      _hostController.text = state.host!;
    }
    if (_portController.text.isEmpty && state.port != null) {
      _portController.text = state.port!.toString();
    }
    if (_workingDirController.text.isEmpty && state.workingDirectory != null) {
      _workingDirController.text = state.workingDirectory!;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server Connection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Configure the Vide server connection.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: videColors.textSecondary,
                ),
          ),
          const SizedBox(height: 20),

          // Host + Port row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Host field
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Host',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _hostController,
                      decoration: InputDecoration(
                        hintText: 'localhost',
                        prefixIcon:
                            const Icon(Icons.computer_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearTestResult(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Port field
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Port',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _portController,
                      decoration: InputDecoration(
                        hintText: '8080',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      onChanged: (_) => _clearTestResult(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Working directory field
          Text(
            'Working Directory',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          _WorkingDirectoryField(
            controller: _workingDirController,
            hostText: _hostController.text.trim(),
            portText: _portController.text.trim(),
            onChanged: _clearTestResult,
          ),
          const SizedBox(height: 20),

          // Connection test result
          if (_testResult != null) _buildTestResultChip(context),
          if (_testResult != null) const SizedBox(height: 16),

          // Test & Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _testingConnection ? null : _testAndSave,
              icon: _testingConnection
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(_testingConnection ? 'Testing...' : 'Test & Save'),
            ),
          ),
        ],
      ),
    );
  }

  void _clearTestResult() {
    if (_testResult != null) {
      setState(() => _testResult = null);
    }
  }

  Future<void> _testAndSave() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final dir = _workingDirController.text.trim();

    if (host.isEmpty || portStr.isEmpty || dir.isEmpty) {
      setState(() {
        _testResult = _ConnectionTestResult(
          success: false,
          message: 'All fields are required',
        );
      });
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _testResult = _ConnectionTestResult(
          success: false,
          message: 'Invalid port number',
        );
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    final success = await widget.sdkState.testConnection(
      host: host,
      port: port,
    );

    if (!mounted) return;

    if (success) {
      widget.sdkState.updateConfig(
        host: host,
        port: port,
        workingDirectory: dir,
      );
      setState(() {
        _testingConnection = false;
        _testResult = _ConnectionTestResult(
          success: true,
          message: 'Connected',
        );
        _showingConfig = false;
      });
    } else {
      setState(() {
        _testingConnection = false;
        _testResult = _ConnectionTestResult(
          success: false,
          message: 'Connection failed - check host and port',
        );
      });
    }
  }

  Widget _buildTestResultChip(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final result = _testResult!;
    final color = result.success ? videColors.success : videColors.error;
    final icon =
        result.success ? Icons.check_circle_outline : Icons.error_outline;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                result.message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screenshot preview
  // ---------------------------------------------------------------------------

  Widget _buildScreenshotPreview(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.md,
        vertical: VideSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: videColors.accent.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.memory(
                  widget.pendingScreenshot!,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onClearScreenshot,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar — delegates to vide_mobile InputBar for feature parity
  // ---------------------------------------------------------------------------

  Widget _buildInputBar(BuildContext context) {
    final isProcessing = widget.sdkState.videState?.isProcessing ?? false;
    final isDisconnected = widget.sdkState.connectionState ==
        VideSdkConnectionState.disconnected;
    final enabled = !isProcessing && !isDisconnected;

    return InputBar(
      controller: _textController,
      enabled: enabled,
      isLoading: isProcessing,
      onSend: _sendMessage,
      onAbort: () => widget.sdkState.abort(),
    );
  }
}

// =============================================================================
// Render item types for flattened message list
// =============================================================================

sealed class _RenderItem {}

class _TextRenderItem implements _RenderItem {
  final ConversationEntry entry;
  final TextContent content;

  _TextRenderItem(this.entry, this.content);
}

class _ToolRenderItem implements _RenderItem {
  final ConversationEntry entry;
  final ToolContent tool;

  _ToolRenderItem(this.entry, this.tool);
}

// =============================================================================
// Per-agent message list — mirrors vide_mobile _MessageList
// =============================================================================

class _MessageList extends StatelessWidget {
  final AgentConversationState? agentState;
  final String agentId;
  final VideAgentStatus agentStatus;
  final List<VideAgent> agents;
  final PermissionRequestEvent? pendingPermission;
  final ScrollController scrollController;
  final ValueChanged<String>? onAgentTap;
  final void Function(ToolContent tool)? onToolTap;

  const _MessageList({
    required this.agentState,
    required this.agentId,
    required this.agentStatus,
    required this.agents,
    required this.pendingPermission,
    required this.scrollController,
    this.onAgentTap,
    this.onToolTap,
  });

  bool get _isAgentBusy =>
      agentStatus == VideAgentStatus.working ||
      agentStatus == VideAgentStatus.waitingForAgent;

  @override
  Widget build(BuildContext context) {
    final messages = agentState?.messages ?? [];

    if (messages.isEmpty && !_isAgentBusy) {
      return const Center(
        child: Text('No messages from this agent yet',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final items = <_RenderItem>[];
    for (final entry in messages) {
      for (final content in entry.content) {
        switch (content) {
          case TextContent():
            if (content.text.isNotEmpty) {
              items.add(_TextRenderItem(entry, content));
            }
          case ToolContent():
            if (!isHiddenTool(content)) {
              items.add(_ToolRenderItem(entry, content));
            }
          case AttachmentContent():
            break;
        }
      }
    }

    if (pendingPermission != null &&
        pendingPermission!.agentId == agentId &&
        items.isNotEmpty) {
      final last = items.last;
      if (last is _ToolRenderItem &&
          last.tool.isExecuting &&
          last.tool.toolName == pendingPermission!.toolName) {
        items.removeLast();
      }
    }

    final showTyping = _isAgentBusy;
    final totalCount = items.length + (showTyping ? 1 : 0);

    if (totalCount == 0) return const SizedBox.shrink();

    return SelectionArea(
      child: ListView.builder(
        reverse: true,
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: VideSpacing.sm),
        itemCount: totalCount,
        itemBuilder: (context, reverseIndex) {
          if (showTyping && reverseIndex == 0) {
            return const TypingIndicator();
          }
          final itemIndex = items.length -
              1 -
              (showTyping ? reverseIndex - 1 : reverseIndex);
          final item = items[itemIndex];
          switch (item) {
            case _TextRenderItem(:final entry, :final content):
              return _MessageBubble(entry: entry, content: content);
            case _ToolRenderItem(:final tool):
              if (isSpawnAgentTool(tool)) {
                return SpawnAgentCard(
                    tool: tool, agents: agents, onTap: onAgentTap);
              }
              if (tool.toolName == 'ExitPlanMode') {
                return PlanResultIndicator(tool: tool);
              }
              return ToolCard(
                  tool: tool, onTap: () => onToolTap?.call(tool));
          }
        },
      ),
    );
  }
}

// =============================================================================
// Message bubble — matches vide_mobile MessageBubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  final ConversationEntry entry;
  final TextContent content;

  const _MessageBubble({required this.entry, required this.content});

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isUser
              ? Border(
                  left: BorderSide(color: videColors.accent, width: 3),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: isUser
            ? Text(
                content.text,
                style: TextStyle(color: colorScheme.onSurface),
              )
            : MarkdownBody(
                data: content.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  code: TextStyle(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: VideRadius.smAll,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                selectable: false,
                softLineBreak: true,
              ),
      ),
    );
  }
}



// =============================================================================
// Session tile — shown in the empty layout for reconnecting
// =============================================================================

class _SessionTile extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VideThemeColors videColors;
  final ColorScheme colorScheme;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.videColors,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(session.createdAt);
    final shortId = session.sessionId.length >= 8
        ? session.sessionId.substring(0, 8)
        : session.sessionId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: videColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: videColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session $shortId',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: videColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: videColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

/// Result of a connection test.
class _ConnectionTestResult {
  final bool success;
  final String message;

  const _ConnectionTestResult({required this.success, required this.message});
}

/// A simple icon button that doesn't use [Tooltip] (which requires an
/// [Overlay] ancestor that isn't available in the builder-injected overlay).
class _InputBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const _InputBarButton({
    required this.icon,
    this.onTap,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

// =============================================================================
// Working directory field with browse button
// =============================================================================

class _WorkingDirectoryField extends StatelessWidget {
  final TextEditingController controller;
  final String hostText;
  final String portText;
  final VoidCallback onChanged;

  const _WorkingDirectoryField({
    required this.controller,
    required this.hostText,
    required this.portText,
    required this.onChanged,
  });

  bool get _canBrowse {
    if (hostText.isEmpty || portText.isEmpty) return false;
    final port = int.tryParse(portText);
    return port != null && port > 0 && port <= 65535;
  }

  Future<void> _openFolderPicker(BuildContext context) async {
    final port = int.parse(portText);
    final client = VideClient(host: hostText, port: port);

    final selectedPath = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FolderPickerSheet(client: client),
    );

    if (selectedPath != null) {
      controller.text = selectedPath;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '/path/to/your/project',
              prefixIcon: const Icon(Icons.folder_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _canBrowse ? () => _openFolderPicker(context) : null,
          icon: const Icon(Icons.search, size: 20),
          tooltip: _canBrowse
              ? 'Browse server filesystem'
              : 'Enter host and port first',
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Folder picker sheet for browsing server filesystem
// =============================================================================

class FolderPickerSheet extends StatefulWidget {
  final VideClient client;

  const FolderPickerSheet({super.key, required this.client});

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
  String? _currentPath;
  List<FileEntry> _entries = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<FileEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final query = _searchQuery.toLowerCase();
    return _entries.where((e) => e.name.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDirectory(null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String? path) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _searchQuery = '';
      _searchController.clear();
    });

    try {
      final entries = await widget.client.listDirectory(parent: path);
      final dirs = entries.where((e) => e.isDirectory).toList();

      if (mounted) {
        setState(() {
          _currentPath = path ?? _deriveParentPath(entries);
          _entries = dirs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _deriveParentPath(List<FileEntry> entries) {
    if (entries.isEmpty) return '/';
    final firstPath = entries.first.path;
    final lastSlash = firstPath.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return firstPath.substring(0, lastSlash);
  }

  String? get _parentPath {
    if (_currentPath == null || _currentPath == '/') return null;
    final lastSlash = _currentPath!.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return _currentPath!.substring(0, lastSlash);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _parentPath != null
                          ? () => _loadDirectory(_parentPath)
                          : null,
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: _parentPath != null
                            ? colorScheme.onSurface
                            : videColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPath ?? '...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _currentPath != null
                          ? () => Navigator.of(context).pop(_currentPath)
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              // Search
              if (!_isLoading && _error == null && _entries.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search folders...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              // Directory listing
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _error!,
                                style: TextStyle(color: videColors.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _filteredEntries.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching folders'
                                      : 'No subdirectories',
                                  style: TextStyle(
                                    color: videColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = _filteredEntries[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.folder_outlined,
                                      color: videColors.accent,
                                      size: 20,
                                    ),
                                    title: Text(
                                      entry.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    dense: true,
                                    onTap: () => _loadDirectory(entry.path),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

