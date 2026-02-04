import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// Floating message input bar with liquid glass effect.
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: VideSpacing.sm,
        right: VideSpacing.sm,
        bottom: VideSpacing.sm + bottomPadding,
      ),
      child: LiquidGlass.withOwnLayer(
        settings: LiquidGlassSettings(
          thickness: 12,
          blur: 20,
          glassColor: colorScheme.surface.withValues(alpha: 0.3),
          refractiveIndex: 1.1,
          lightIntensity: 0.3,
        ),
        shape: const LiquidRoundedSuperellipse(borderRadius: 24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        if (_hasText && widget.enabled && !widget.isLoading) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final text = widget.controller.text;
                            if (text.endsWith('\n')) {
                              widget.controller.text = text.substring(0, text.length - 1);
                            }
                            _handleSend();
                          });
                        }
                      }
                    },
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled && !widget.isLoading,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: widget.isLoading ? 'Agent is working...' : 'Type a message...',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
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
        ),
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
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: enabled ? videColors.accent : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        onPressed: enabled ? onSend : null,
        icon: Icon(
          Icons.send_rounded,
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
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: videColors.errorContainer,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
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
