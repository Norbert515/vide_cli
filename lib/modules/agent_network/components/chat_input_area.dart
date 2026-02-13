import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/components/queue_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart';
import 'package:vide_cli/modules/agent_network/components/attachment_text_field.dart';
import 'package:vide_cli/modules/agent_network/components/context_usage_section.dart';
import 'package:vide_cli/modules/permissions/components/ask_user_question_dialog.dart';
import 'package:vide_cli/modules/permissions/components/permission_dialog.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/modules/agent_network/state/prompt_history_provider.dart';
import 'package:vide_core/vide_core.dart';

/// The bottom input area of the agent chat, containing the queue indicator,
/// loading indicator, permission/question dialogs, text field, command result,
/// and context usage section.
class ChatInputArea extends StatelessComponent {
  final String agentId;
  final String? queuedMessage;
  final bool isAgentWorking;
  final bool showQuitWarning;
  final bool hasPlanApproval;
  final String? commandResult;
  final bool commandResultIsError;
  final AgentConversationState? conversation;
  final String? model;
  final VoidCallback onClearQueue;
  final void Function(VideMessage message) onSendMessage;
  final void Function(String command) onCommand;
  final void Function(
    PermissionRequest request,
    bool granted,
    bool remember, {
    String? patternOverride,
    String? denyReason,
  })
  onPermissionResponse;
  final void Function(
    AskUserQuestionUIRequest request,
    Map<String, String> answers,
  )
  onAskUserQuestionResponse;
  final VoidCallback onEscape;
  final List<CommandSuggestion> Function(String prefix) commandSuggestions;

  const ChatInputArea({
    required this.agentId,
    required this.queuedMessage,
    required this.isAgentWorking,
    required this.showQuitWarning,
    required this.hasPlanApproval,
    required this.commandResult,
    required this.commandResultIsError,
    required this.conversation,
    required this.model,
    required this.onClearQueue,
    required this.onSendMessage,
    required this.onCommand,
    required this.onPermissionResponse,
    required this.onAskUserQuestionResponse,
    required this.onEscape,
    required this.commandSuggestions,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Get the current permission queue state from the provider
    final permissionQueueState = context.watch(permissionStateProvider);
    final currentPermissionRequest = permissionQueueState.current;

    // Get the current AskUserQuestion queue state from the provider
    final askUserQuestionQueueState = context.watch(
      askUserQuestionStateProvider,
    );
    final currentAskUserQuestionRequest = askUserQuestionQueueState.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show queued message indicator above the generating indicator
        if (queuedMessage != null)
          QueueIndicator(queuedText: queuedMessage!, onClear: onClearQueue),

        // Loading indicator row - always 1 cell height to prevent layout jumps
        if (isAgentWorking &&
            !hasPlanApproval &&
            currentAskUserQuestionRequest == null &&
            currentPermissionRequest == null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              EnhancedLoadingIndicator(agentId: agentId),
              SizedBox(width: 2),
              Text(
                '(Press ESC to stop)',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            ],
          )
        else
          Text(' '), // Reserve 1 line when loading indicator is hidden
        // Show quit warning if active
        if (showQuitWarning)
          Text(
            '(Press Ctrl+C again to exit)',
            style: TextStyle(
              color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),

        // Show AskUserQuestion dialog above text field (if active)
        if (!hasPlanApproval && currentAskUserQuestionRequest != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show queue length if there are more questions waiting
              if (askUserQuestionQueueState.queueLength > 1)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                  child: Text(
                    'Question 1 of ${askUserQuestionQueueState.queueLength} (${askUserQuestionQueueState.queueLength - 1} more in queue)',
                    style: TextStyle(
                      color: theme.base.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              AskUserQuestionDialog(
                request: currentAskUserQuestionRequest,
                onSubmit: (answers) => onAskUserQuestionResponse(
                  currentAskUserQuestionRequest,
                  answers,
                ),
                key: Key(
                  'ask_user_question_${currentAskUserQuestionRequest.requestId}',
                ),
              ),
            ],
          )
        // Show permission dialog above text field (if active)
        else if (currentPermissionRequest != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show queue length if there are more requests waiting
              if (permissionQueueState.queueLength > 1)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                  child: Text(
                    'Permission 1 of ${permissionQueueState.queueLength} (${permissionQueueState.queueLength - 1} more in queue)',
                    style: TextStyle(
                      color: theme.base.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              PermissionDialog.fromRequest(
                request: currentPermissionRequest,
                onResponse:
                    (
                      granted,
                      remember, {
                      String? patternOverride,
                      String? denyReason,
                    }) => onPermissionResponse(
                      currentPermissionRequest,
                      granted,
                      remember,
                      patternOverride: patternOverride,
                      denyReason: denyReason,
                    ),
                key: Key('permission_${currentPermissionRequest.requestId}'),
              ),
            ],
          ),

        // Text field - rendered when no dialogs are active
        if (!hasPlanApproval &&
            currentAskUserQuestionRequest == null &&
            currentPermissionRequest == null)
          _buildTextField(context),

        // Command result feedback
        if (commandResult != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              commandResult!,
              style: TextStyle(
                color: commandResultIsError
                    ? theme.base.error
                    : theme.base.onSurface.withOpacity(TextOpacity.secondary),
              ),
            ),
          ),

        // Context usage bar with compact button
        ContextUsageSection(conversation: conversation, model: model),
      ],
    );
  }

  Component _buildTextField(BuildContext context) {
    return Builder(
      builder: (context) {
        final promptHistory = context.watch(promptHistoryProvider);
        final pendingText = context.watch(pendingInputTextProvider);
        // Text field is focused when neither sidebar has focus
        final leftSidebarFocused = context.watch(sidebarFocusProvider);
        final rightSidebarFocused = context.watch(gitSidebarFocusProvider);
        final textFieldFocused = !leftSidebarFocused && !rightSidebarFocused;

        return AttachmentTextField(
          focused: textFieldFocused,
          enabled: true, // Always enabled - messages queue during processing
          placeholder: 'Type a message...',
          initialText: pendingText,
          onTextChanged: (text) =>
              context.read(pendingInputTextProvider.notifier).state = text,
          onSubmit: (message) {
            // Clear pending text on submit
            context.read(pendingInputTextProvider.notifier).state = '';
            onSendMessage(message);
          },
          onCommand: (cmd) {
            // Clear pending text on command
            context.read(pendingInputTextProvider.notifier).state = '';
            onCommand(cmd);
          },
          commandSuggestions: commandSuggestions,
          promptHistory: promptHistory,
          onPromptSubmitted: (prompt) =>
              context.read(promptHistoryProvider.notifier).addPrompt(prompt),
          onLeftEdge: () =>
              context.read(sidebarFocusProvider.notifier).state = true,
          onRightEdge: () =>
              context.read(gitSidebarFocusProvider.notifier).state = true,
          onEscape: onEscape,
        );
      },
    );
  }
}
