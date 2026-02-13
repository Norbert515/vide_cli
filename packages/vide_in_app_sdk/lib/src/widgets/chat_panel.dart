import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../services/voice_input_service.dart';
import '../state/sdk_state.dart';

/// Slide-up chat panel for interacting with the Vide AI assistant.
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
  final _serverUrlController = TextEditingController();
  final _workingDirController = TextEditingController();
  bool _voiceInitialized = false;
  bool _showingConfig = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _serverUrlController.dispose();
    _workingDirController.dispose();
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
          content: _bytesToBase64(widget.pendingScreenshot!),
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

  String _bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
        return Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          color: Theme.of(context).colorScheme.surface,
          elevation: 16,
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              _buildHeader(context),

              const Divider(height: 1),

              // Error banner
              if (widget.sdkState.connectionState ==
                  VideSdkConnectionState.error)
                _buildErrorBanner(context),

              // Messages
              Expanded(child: _buildMessageList(context)),

              // Pending screenshot preview
              if (widget.pendingScreenshot != null) _buildScreenshotPreview(context),

              // Permission banner
              _buildPermissionBanner(context),

              // Input bar
              _buildInputBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = widget.sdkState;
    final connectionColor = switch (state.connectionState) {
      VideSdkConnectionState.connected => Colors.green,
      VideSdkConnectionState.connecting => Colors.orange,
      VideSdkConnectionState.error => Colors.red,
      VideSdkConnectionState.disconnected => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connectionColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _headerTitle(state),
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.hasActiveSession && state.videState?.isProcessing == true)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 8),
          _InputBarButton(
            icon: Icons.settings,
            onTap: () => setState(() => _showingConfig = !_showingConfig),
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

  Widget _buildErrorBanner(BuildContext context) {
    final message = widget.sdkState.errorMessage ?? 'Connection failed';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => widget.sdkState.disconnect(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.refresh, size: 16, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    if (_showingConfig || !widget.sdkState.isConfigured) {
      return _buildConfigForm(context);
    }

    final session = widget.sdkState.session;
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Start a conversation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Describe what you want to build or fix.\nAttach a screenshot for visual context.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get conversation for main agent
    final mainAgent = session.state.mainAgent;
    if (mainAgent == null) return const SizedBox.shrink();

    final conversation = session.getConversation(mainAgent.id);
    if (conversation == null) return const SizedBox.shrink();

    final messages = conversation.messages;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final entry = messages[index];
        return _buildConversationEntry(context, entry);
      },
    );
  }

  Widget _buildConfigForm(BuildContext context) {
    final state = widget.sdkState;
    if (_serverUrlController.text.isEmpty && state.serverUrl != null) {
      _serverUrlController.text = state.serverUrl!;
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
            'Configuration',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Configure the Vide server connection.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
          const SizedBox(height: 20),
          Text('Server URL', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          TextField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              hintText: 'localhost:8080',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          Text(
            'Working Directory',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _workingDirController,
            decoration: InputDecoration(
              hintText: '/path/to/your/project',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final url = _serverUrlController.text.trim();
                final dir = _workingDirController.text.trim();
                if (url.isNotEmpty && dir.isNotEmpty) {
                  state.updateConfig(serverUrl: url, workingDirectory: dir);
                  setState(() => _showingConfig = false);
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationEntry(BuildContext context, ConversationEntry entry) {
    final isUser = entry.role == 'user';
    final widgets = <Widget>[];

    for (final content in entry.content) {
      switch (content) {
        case TextContent():
          if (content.text.isEmpty) continue;
          widgets.add(
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  content.text,
                  style: TextStyle(
                    color: isUser
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );

        case ToolContent():
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.build_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.toolName,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  if (content.result != null)
                    Icon(
                      content.isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: content.isError ? Colors.red : Colors.green,
                    )
                  else if (content.isExecuting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          );

        case AttachmentContent():
          // Show a small attachment indicator
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${content.attachments.length} attachment(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildScreenshotPreview(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.memory(
              widget.pendingScreenshot!,
              width: double.infinity,
              height: 80,
              fit: BoxFit.cover,
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
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context) {
    final session = widget.sdkState.session;
    final pending = session?.pendingPermissionRequest;
    if (pending == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permission: ${pending.toolName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (pending.toolInput.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _summarizeToolInput(pending.toolInput),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.orange.shade800,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  widget.sdkState.respondToPermission(
                    pending.requestId,
                    allow: false,
                  );
                },
                child: const Text('Deny'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  widget.sdkState.respondToPermission(
                    pending.requestId,
                    allow: true,
                  );
                },
                child: const Text('Allow'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _summarizeToolInput(Map<String, dynamic> input) {
    if (input.containsKey('command')) return input['command'].toString();
    if (input.containsKey('file_path')) return input['file_path'].toString();
    if (input.containsKey('pattern')) return input['pattern'].toString();
    return input.entries.take(2).map((e) => '${e.key}: ${e.value}').join(', ');
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            // Screenshot button
            _InputBarButton(
              icon: Icons.photo_camera_outlined,
              onTap: widget.onScreenshotRequest,
            ),

            // Voice button
            ListenableBuilder(
              listenable: widget.voiceService,
              builder: (context, _) {
                return _InputBarButton(
                  icon: widget.voiceService.isListening
                      ? Icons.mic
                      : Icons.mic_none,
                  color: widget.voiceService.isListening ? Colors.red : null,
                  onTap: _toggleVoice,
                );
              },
            ),

            // Text field
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: widget.sdkState.hasActiveSession
                      ? 'Message...'
                      : 'What do you want to build?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),

            const SizedBox(width: 4),

            // Send button
            _InputBarButton(
              icon: Icons.send,
              onTap: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple icon button that doesn't use [Tooltip] (which requires an
/// [Overlay] ancestor that isn't available in the builder-injected overlay).
class _InputBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _InputBarButton({
    required this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
