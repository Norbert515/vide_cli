import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// Terminal-style message input bar.
class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onSend;
  final VoidCallback? onAbort;

  const InputBar({
    super.key,
    required this.controller,
    this.enabled = true,
    this.isLoading = false,
    this.onSend,
    this.onAbort,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _handleSend() {
    if (_hasText && widget.onSend != null) {
      widget.onSend!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Container(
      padding: EdgeInsets.only(
        left: VideSpacing.md,
        right: VideSpacing.sm,
        top: VideSpacing.sm,
        bottom: VideSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Terminal prompt
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '>',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: videColors.textTertiary,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled && !widget.isLoading,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: widget.isLoading ? 'Agent is working...' : 'Type a message...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: VideRadius.smAll,
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: VideRadius.smAll,
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: VideRadius.smAll,
                    borderSide: BorderSide(color: videColors.accent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.isLoading)
            _AbortButton(onAbort: widget.onAbort)
          else
            _SendButton(
              enabled: _hasText && widget.enabled,
              onSend: _handleSend,
            ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSend;

  const _SendButton({
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: enabled ? videColors.accent : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: enabled ? onSend : null,
        icon: Icon(
          Icons.arrow_upward_rounded,
          color: enabled ? VideColors.background : colorScheme.onSurfaceVariant,
        ),
        tooltip: 'Send',
      ),
    );
  }
}

class _AbortButton extends StatelessWidget {
  final VoidCallback? onAbort;

  const _AbortButton({this.onAbort});

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: videColors.errorContainer,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onAbort,
        icon: Icon(
          Icons.stop_rounded,
          color: videColors.error,
        ),
        tooltip: 'Stop',
      ),
    );
  }
}
